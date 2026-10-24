-- Migration 0004: Scheduled background jobs (pg_cron & pg_net), Vault configuration, and manual trigger

-- 1. Enable pg_cron, pg_net, and supabase_vault extensions
create extension if not exists "pg_net" with schema extensions;
create extension if not exists "pg_cron" with schema extensions;
create extension if not exists "supabase_vault" cascade;

-- 2. Add post-treatment care tracking columns to appointments
alter table appointments
  add column if not exists post_care_claimed_at timestamptz,
  add column if not exists post_care_sent_at timestamptz,
  add column if not exists post_care_attempts int not null default 0;

create index if not exists idx_appointments_post_care
  on appointments (status, post_care_sent_at, starts_at);

-- 3. Update claim_due_reminders with configurable hours window (defaults to 23h - 25h)
create or replace function claim_due_reminders(
  limit_count int default 50,
  min_hours int default 23,
  max_hours int default 25
)
returns setof appointments
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with due as (
    select id
    from appointments
    where reminder_sent_at is null
      and status in ('pending', 'confirmed')
      and reminder_attempts < 3
      and (reminder_claimed_at is null or reminder_claimed_at < now() - interval '15 minutes')
      and starts_at between (now() + (min_hours || ' hours')::interval) and (now() + (max_hours || ' hours')::interval)
    order by starts_at asc
    limit limit_count
    for update skip locked
  )
  update appointments a
  set reminder_claimed_at = now(),
      reminder_attempts = a.reminder_attempts + 1
  from due
  where a.id = due.id
  returning a.*;
end;
$$;

-- 4. Create claim_due_post_care for post-treatment follow-up dispatcher (idempotent with SKIP LOCKED)
create or replace function claim_due_post_care(limit_count int default 50)
returns setof appointments
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with due as (
    select id
    from appointments
    where status = 'completed'
      and post_care_sent_at is null
      and post_care_attempts < 3
      and (post_care_claimed_at is null or post_care_claimed_at < now() - interval '15 minutes')
      and starts_at <= now() - interval '2 hours'
      and starts_at >= now() - interval '48 hours'
    order by starts_at asc
    limit limit_count
    for update skip locked
  )
  update appointments a
  set post_care_claimed_at = now(),
      post_care_attempts = a.post_care_attempts + 1
  from due
  where a.id = due.id
  returning a.*;
end;
$$;

-- 5. Helper function to invoke Edge Functions via pg_net using secrets stored in Vault
create or replace function trigger_edge_job(job_name text, query_params text default '')
returns bigint
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  base_url text;
  secret text;
  request_id bigint;
  target_url text;
begin
  -- Fetch secrets from Supabase Vault (decrypted_secrets view)
  begin
    select decrypted_secret into base_url from vault.decrypted_secrets where name = 'edge_function_base_url' limit 1;
    select decrypted_secret into secret from vault.decrypted_secrets where name = 'job_secret' limit 1;
  exception when others then
    base_url := null;
    secret := null;
  end;

  -- Default fallback for local testing if not yet added to vault
  if base_url is null or base_url = '' then
    base_url := 'http://127.0.0.1:54321/functions/v1';
  end if;

  target_url := rtrim(base_url, '/') || '/' || job_name;
  if query_params is not null and query_params <> '' then
    target_url := target_url || '?' || query_params;
  end if;

  select net.http_post(
    url := target_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-job-secret', coalesce(secret, 'caretrack_dev_job_secret')
    ),
    body := '{}'::jsonb
  ) into request_id;

  return request_id;
end;
$$;

-- 6. Manual trigger function for Demo Mode (accessible by owner or doctor only)
create or replace function run_scheduled_job_manual(job_name text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  caller_role user_role;
  result jsonb;
  request_id bigint;
  missed_count int;
begin
  caller_role := auth_role();
  if caller_role is null or caller_role not in ('owner', 'doctor') then
    raise exception 'Unauthorized: Only clinic owners and doctors can manually trigger background jobs';
  end if;

  case job_name
    when 'send-notifications' then
      request_id := trigger_edge_job('send-notifications');
      result := jsonb_build_object('job', job_name, 'status', 'dispatched', 'request_id', request_id);

    when 'mark-missed' then
      missed_count := mark_missed_appointments();
      result := jsonb_build_object('job', job_name, 'status', 'completed', 'updated_appointments', missed_count);

    when 'medication-reminders' then
      request_id := trigger_edge_job('medication-reminders', 'mode=dispatch');
      result := jsonb_build_object('job', job_name, 'status', 'dispatched', 'request_id', request_id);

    when 'post-treatment-care' then
      request_id := trigger_edge_job('post-treatment-care');
      result := jsonb_build_object('job', job_name, 'status', 'dispatched', 'request_id', request_id);

    when 'all' then
      missed_count := mark_missed_appointments();
      perform trigger_edge_job('send-notifications');
      perform trigger_edge_job('medication-reminders', 'mode=dispatch');
      perform trigger_edge_job('post-treatment-care');
      result := jsonb_build_object('job', 'all', 'status', 'dispatched', 'missed_marked', missed_count);

    else
      raise exception 'Unknown job name: %. Valid options are: send-notifications, mark-missed, medication-reminders, post-treatment-care, all', job_name;
  end case;

  -- Record audit log
  insert into audit_logs (clinic_id, user_id, action, entity, entity_id)
  values (auth_clinic(), auth.uid(), 'MANUAL_JOB_TRIGGER: ' || job_name, 'cron_jobs', null);

  return result;
end;
$$;

-- 7. Schedule pg_cron recurring jobs safely
do $cron_setup$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    -- Unschedule existing if any
    begin
      if exists (select 1 from cron.job where jobname = 'send-notifications-hourly') then
        perform cron.unschedule('send-notifications-hourly');
      end if;
      if exists (select 1 from cron.job where jobname = 'mark-missed-appointments-hourly') then
        perform cron.unschedule('mark-missed-appointments-hourly');
      end if;
      if exists (select 1 from cron.job where jobname = 'medication-reminders-daily') then
        perform cron.unschedule('medication-reminders-daily');
      end if;
      if exists (select 1 from cron.job where jobname = 'post-treatment-care-hourly') then
        perform cron.unschedule('post-treatment-care-hourly');
      end if;
    exception when others then
      -- Ignore cleanup errors if cron tables aren't fully initialized
    end;

    -- Schedule:
    -- 1) Hourly send-notifications: at :00 every hour
    perform cron.schedule('send-notifications-hourly', '0 * * * *', $cmd$ select trigger_edge_job('send-notifications'); $cmd$);

    -- 2) Hourly mark-missed-appointments: at :05 every hour
    perform cron.schedule('mark-missed-appointments-hourly', '5 * * * *', $cmd$ select mark_missed_appointments(); $cmd$);

    -- 3) Daily medication reminder dispatcher: at 08:00 IST (02:30 UTC)
    perform cron.schedule('medication-reminders-daily', '30 2 * * *', $cmd$ select trigger_edge_job('medication-reminders', 'mode=dispatch'); $cmd$);

    -- 4) Hourly post-treatment care message dispatcher: at :15 every hour
    perform cron.schedule('post-treatment-care-hourly', '15 * * * *', $cmd$ select trigger_edge_job('post-treatment-care'); $cmd$);
  end if;
exception when others then
  raise notice 'pg_cron job setup deferred or running in non-cron environment: %', sqlerrm;
end;
$cron_setup$;
