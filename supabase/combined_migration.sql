create extension if not exists "pgcrypto";
create type user_role as enum ('owner','doctor','receptionist');
create type appt_status as enum ('pending','confirmed','reschedule_requested','rescheduled','missed','completed','cancelled');

create table clinics (id uuid primary key default gen_random_uuid(), name text not null, slug text unique, timezone text not null default 'Asia/Kolkata', settings jsonb not null default '{}');
create table profiles (id uuid primary key references auth.users(id) on delete cascade, clinic_id uuid not null references clinics(id), role user_role not null, full_name text not null, active boolean not null default true);
create table patients (id uuid primary key default gen_random_uuid(), clinic_id uuid not null references clinics(id), doctor_id uuid not null references profiles(id), full_name text not null, phone text, email text, language text not null default 'en', messaging_consent boolean not null default false, ai_consent boolean not null default false, medical_notes text, created_at timestamptz not null default now());
create table prescriptions (id uuid primary key default gen_random_uuid(), clinic_id uuid not null references clinics(id), patient_id uuid not null references patients(id) on delete cascade, doctor_id uuid not null references profiles(id), medicines jsonb not null default '[]', follow_up_date date, verified_at timestamptz, created_at timestamptz not null default now());
create table appointments (id uuid primary key default gen_random_uuid(), clinic_id uuid not null references clinics(id), patient_id uuid not null references patients(id) on delete cascade, doctor_id uuid not null references profiles(id), starts_at timestamptz not null, status appt_status not null default 'pending', token_hash text, token_expires_at timestamptz, reminder_claimed_at timestamptz, reminder_sent_at timestamptz, reminder_attempts int not null default 0, created_at timestamptz not null default now(), unique (doctor_id, starts_at));
create table notifications (id uuid primary key default gen_random_uuid(), clinic_id uuid not null references clinics(id), appointment_id uuid references appointments(id) on delete set null, patient_id uuid references patients(id) on delete set null, channel text not null, status text not null, recipient_masked text, provider_message_id text, error text, created_at timestamptz not null default now());
create table audit_logs (id bigint generated always as identity primary key, clinic_id uuid, user_id uuid, action text not null, entity text, entity_id uuid, created_at timestamptz not null default now());

create index on appointments (doctor_id, starts_at);
create index on appointments (clinic_id, status, starts_at);
create index on patients (clinic_id, doctor_id);

create function auth_clinic() returns uuid language sql stable security definer set search_path = public as $$ select clinic_id from profiles where id = auth.uid() and active $$;
create function auth_role() returns user_role language sql stable security definer set search_path = public as $$ select role from profiles where id = auth.uid() and active $$;
alter table clinics enable row level security;
alter table profiles enable row level security;
alter table patients enable row level security;
alter table prescriptions enable row level security;
alter table appointments enable row level security;
alter table notifications enable row level security;
alter table audit_logs enable row level security;

create policy clinic_read on clinics for select using (id = auth_clinic());
create policy profile_read on profiles for select using (clinic_id = auth_clinic());
-- profiles: no client insert/update/delete. Role/clinic/active change only via service role.
create policy patients_select on patients for select using (clinic_id = auth_clinic() and (doctor_id = auth.uid() or auth_role() in ('owner','receptionist')));
create policy patients_write on patients for all using (clinic_id = auth_clinic() and (doctor_id = auth.uid() or auth_role() = 'receptionist')) with check (clinic_id = auth_clinic());
create policy rx_doctor on prescriptions for all using (clinic_id = auth_clinic() and doctor_id = auth.uid()) with check (clinic_id = auth_clinic() and doctor_id = auth.uid());
create policy appt_select on appointments for select using (clinic_id = auth_clinic() and (doctor_id = auth.uid() or auth_role() in ('owner','receptionist')));
create policy appt_write on appointments for all using (clinic_id = auth_clinic() and (doctor_id = auth.uid() or auth_role() = 'receptionist')) with check (clinic_id = auth_clinic());
create policy notif_select on notifications for select using (clinic_id = auth_clinic());
-- notifications and audit_logs: no client write policies (service role only).
-- Migration 0002: Advanced features, clinical schemas, functions and storage policies

-- 1. Treatment plan templates
create table treatment_plan_templates (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references clinics(id) on delete cascade,
  doctor_id uuid references profiles(id) on delete set null,
  title text not null,
  description text,
  stages jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

-- 2. Treatment plans
create table treatment_plans (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references clinics(id) on delete cascade,
  patient_id uuid not null references patients(id) on delete cascade,
  doctor_id uuid not null references profiles(id) on delete restrict,
  template_id uuid references treatment_plan_templates(id) on delete set null,
  title text not null,
  status text not null default 'active' check (status in ('active', 'paused', 'completed', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. Plan stages
create table plan_stages (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references clinics(id) on delete cascade,
  plan_id uuid not null references treatment_plans(id) on delete cascade,
  stage_order int not null default 1,
  name text not null,
  interval_days_from_previous int not null default 0,
  appointment_id uuid references appointments(id) on delete set null,
  status text not null default 'pending' check (status in ('pending', 'scheduled', 'completed', 'skipped')),
  notes text,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

-- 4. Doctor availability, breaks, leave
create table availability (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references clinics(id) on delete cascade,
  doctor_id uuid not null references profiles(id) on delete cascade,
  day_of_week int check (day_of_week between 0 and 6), -- 0=Sunday, 6=Saturday
  start_time time not null,
  end_time time not null,
  slot_duration_minutes int not null default 30,
  breaks jsonb not null default '[]'::jsonb,
  is_leave boolean not null default false,
  specific_date date,
  created_at timestamptz not null default now()
);

-- 5. Clinic holidays
create table clinic_holidays (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references clinics(id) on delete cascade,
  holiday_date date not null,
  name text not null,
  created_at timestamptz not null default now(),
  unique (clinic_id, holiday_date)
);

-- 6. Two-way WhatsApp conversations & messages
create table conversations (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references clinics(id) on delete cascade,
  patient_id uuid not null references patients(id) on delete cascade,
  phone text not null,
  status text not null default 'open' check (status in ('open', 'resolved')),
  is_urgent boolean not null default false,
  assigned_to uuid references profiles(id) on delete set null,
  last_message_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references clinics(id) on delete cascade,
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_type text not null check (sender_type in ('patient', 'staff', 'system')),
  sender_id uuid references profiles(id) on delete set null,
  body text not null,
  direction text not null check (direction in ('inbound', 'outbound')),
  channel text not null default 'whatsapp',
  is_urgent boolean not null default false,
  created_at timestamptz not null default now()
);

-- 7. Recall campaigns
create table recall_campaigns (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references clinics(id) on delete cascade,
  created_by uuid references profiles(id) on delete set null,
  name text not null,
  criteria jsonb not null default '{}'::jsonb,
  template_text text not null,
  target_count int not null default 0,
  sent_count int not null default 0,
  status text not null default 'draft' check (status in ('draft', 'scheduled', 'running', 'completed', 'cancelled')),
  created_at timestamptz not null default now()
);

-- 8. Medication schedules
create table medication_schedules (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references clinics(id) on delete cascade,
  prescription_id uuid references prescriptions(id) on delete cascade,
  patient_id uuid not null references patients(id) on delete cascade,
  doctor_id uuid not null references profiles(id) on delete cascade,
  medicine_name text not null,
  dosage text not null,
  timing jsonb not null default '[]'::jsonb,
  start_date date not null,
  end_date date not null,
  is_active boolean not null default true,
  adherence_logs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

-- 9. Patient feedback
create table feedback (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references clinics(id) on delete cascade,
  appointment_id uuid references appointments(id) on delete set null,
  patient_id uuid not null references patients(id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

-- 10. Consents
create table consents (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references clinics(id) on delete cascade,
  patient_id uuid not null references patients(id) on delete cascade,
  type text not null, -- 'messaging', 'ai', 'treatment'
  granted boolean not null default true,
  granted_at timestamptz not null default now(),
  method text not null, -- 'in_person', 'whatsapp_opt_in', 'web_form', etc.
  notes text,
  created_at timestamptz not null default now()
);

-- Indexes
create index on treatment_plans (clinic_id, patient_id);
create index on plan_stages (plan_id, stage_order);
create index on availability (clinic_id, doctor_id, day_of_week);
create index on clinic_holidays (clinic_id, holiday_date);
create index on conversations (clinic_id, status, is_urgent);
create index on messages (conversation_id, created_at);
create index on medication_schedules (clinic_id, patient_id, is_active);
create index on consents (clinic_id, patient_id, type);

-- Enable RLS on all new tables
alter table treatment_plan_templates enable row level security;
alter table treatment_plans enable row level security;
alter table plan_stages enable row level security;
alter table availability enable row level security;
alter table clinic_holidays enable row level security;
alter table conversations enable row level security;
alter table messages enable row level security;
alter table recall_campaigns enable row level security;
alter table medication_schedules enable row level security;
alter table feedback enable row level security;
alter table consents enable row level security;

-- Privilege escalation prevention trigger on profiles
create or replace function prevent_profile_privilege_escalation()
returns trigger
language plpgsql
security definer
as $$
begin
  -- If invoked via service_role, allow updates
  if auth.role() = 'service_role' then
    return new;
  end if;

  -- Disallow changing role, clinic_id, or active flag by normal users
  if old.role is distinct from new.role then
    raise exception 'Changing user role is not permitted';
  end if;
  if old.clinic_id is distinct from new.clinic_id then
    raise exception 'Changing user clinic is not permitted';
  end if;
  if old.active is distinct from new.active then
    raise exception 'Changing active status is not permitted';
  end if;

  return new;
end;
$$;

create trigger tr_prevent_profile_privilege_escalation
before update on profiles
for each row
execute function prevent_profile_privilege_escalation();

-- RLS Policies for new tables

-- treatment_plan_templates
create policy template_select on treatment_plan_templates
  for select using (clinic_id = auth_clinic());
create policy template_write on treatment_plan_templates
  for all using (clinic_id = auth_clinic() and auth_role() in ('owner', 'doctor'))
  with check (clinic_id = auth_clinic() and auth_role() in ('owner', 'doctor'));

-- treatment_plans
create policy plan_select on treatment_plans
  for select using (clinic_id = auth_clinic() and (doctor_id = auth.uid() or auth_role() in ('owner', 'receptionist')));
create policy plan_write on treatment_plans
  for all using (clinic_id = auth_clinic() and (doctor_id = auth.uid() or auth_role() = 'receptionist'))
  with check (clinic_id = auth_clinic() and (doctor_id = auth.uid() or auth_role() = 'receptionist'));

-- plan_stages
create policy stage_select on plan_stages
  for select using (clinic_id = auth_clinic());
create policy stage_write on plan_stages
  for all using (clinic_id = auth_clinic() and auth_role() in ('owner', 'doctor', 'receptionist'))
  with check (clinic_id = auth_clinic() and auth_role() in ('owner', 'doctor', 'receptionist'));

-- availability
create policy availability_select on availability
  for select using (clinic_id = auth_clinic());
create policy availability_write on availability
  for all using (clinic_id = auth_clinic() and (doctor_id = auth.uid() or auth_role() = 'owner'))
  with check (clinic_id = auth_clinic() and (doctor_id = auth.uid() or auth_role() = 'owner'));

-- clinic_holidays
create policy holidays_select on clinic_holidays
  for select using (clinic_id = auth_clinic());
create policy holidays_write on clinic_holidays
  for all using (clinic_id = auth_clinic() and auth_role() = 'owner')
  with check (clinic_id = auth_clinic() and auth_role() = 'owner');

-- conversations
create policy conversations_select on conversations
  for select using (clinic_id = auth_clinic());
create policy conversations_write on conversations
  for all using (clinic_id = auth_clinic() and auth_role() in ('owner', 'doctor', 'receptionist'))
  with check (clinic_id = auth_clinic() and auth_role() in ('owner', 'doctor', 'receptionist'));

-- messages
create policy messages_select on messages
  for select using (clinic_id = auth_clinic());
create policy messages_write on messages
  for all using (clinic_id = auth_clinic() and auth_role() in ('owner', 'doctor', 'receptionist'))
  with check (clinic_id = auth_clinic() and auth_role() in ('owner', 'doctor', 'receptionist'));

-- recall_campaigns
create policy recall_select on recall_campaigns
  for select using (clinic_id = auth_clinic());
create policy recall_write on recall_campaigns
  for all using (clinic_id = auth_clinic() and auth_role() in ('owner', 'doctor'))
  with check (clinic_id = auth_clinic() and auth_role() in ('owner', 'doctor'));

-- medication_schedules
create policy medication_select on medication_schedules
  for select using (clinic_id = auth_clinic() and (doctor_id = auth.uid() or auth_role() in ('owner', 'receptionist')));
create policy medication_write on medication_schedules
  for all using (clinic_id = auth_clinic() and (doctor_id = auth.uid() or auth_role() = 'owner'))
  with check (clinic_id = auth_clinic() and (doctor_id = auth.uid() or auth_role() = 'owner'));

-- feedback
create policy feedback_select on feedback
  for select using (clinic_id = auth_clinic());
create policy feedback_insert on feedback
  for insert with check (clinic_id = auth_clinic());

-- consents
create policy consents_select on consents
  for select using (clinic_id = auth_clinic());
create policy consents_write on consents
  for all using (clinic_id = auth_clinic() and auth_role() in ('owner', 'doctor', 'receptionist'))
  with check (clinic_id = auth_clinic() and auth_role() in ('owner', 'doctor', 'receptionist'));

-- 3. SQL Functions

-- dashboard_counters: returns today, 3 days, 7 days, overdue counts
create or replace function dashboard_counters()
returns jsonb
language plpgsql
security invoker
as $$
declare
  curr_clinic uuid;
  curr_doc uuid;
  tz text;
  now_tz timestamptz;
  today_start timestamptz;
  today_end timestamptz;
  three_days_end timestamptz;
  seven_days_end timestamptz;
  c_today int;
  c_3days int;
  c_7days int;
  c_overdue int;
begin
  curr_clinic := auth_clinic();
  curr_doc := auth.uid();

  select coalesce(timezone, 'Asia/Kolkata') into tz from clinics where id = curr_clinic;
  if tz is null then
    tz := 'Asia/Kolkata';
  end if;

  now_tz := now() at time zone tz;
  today_start := date_trunc('day', now_tz);
  today_end := today_start + interval '1 day';
  three_days_end := today_start + interval '4 days';
  seven_days_end := today_start + interval '8 days';

  -- Today count
  select count(*) into c_today
  from appointments
  where clinic_id = curr_clinic
    and (doctor_id = curr_doc or auth_role() in ('owner', 'receptionist'))
    and starts_at >= today_start and starts_at < today_end
    and status != 'cancelled';

  -- Next 3 days count (excluding today)
  select count(*) into c_3days
  from appointments
  where clinic_id = curr_clinic
    and (doctor_id = curr_doc or auth_role() in ('owner', 'receptionist'))
    and starts_at >= today_end and starts_at < three_days_end
    and status != 'cancelled';

  -- Next 7 days count (excluding today)
  select count(*) into c_7days
  from appointments
  where clinic_id = curr_clinic
    and (doctor_id = curr_doc or auth_role() in ('owner', 'receptionist'))
    and starts_at >= today_end and starts_at < seven_days_end
    and status != 'cancelled';

  -- Overdue count: past start time and pending or reschedule_requested
  select count(*) into c_overdue
  from appointments
  where clinic_id = curr_clinic
    and (doctor_id = curr_doc or auth_role() in ('owner', 'receptionist'))
    and starts_at < now()
    and status in ('pending', 'reschedule_requested');

  return jsonb_build_object(
    'today', coalesce(c_today, 0),
    'in_3_days', coalesce(c_3days, 0),
    'in_7_days', coalesce(c_7days, 0),
    'overdue', coalesce(c_overdue, 0)
  );
end;
$$;

-- claim_due_reminders: concurrency-safe reminder claiming with SKIP LOCKED
create or replace function claim_due_reminders(limit_count int default 20)
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
      and starts_at between now() and (now() + interval '26 hours')
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

-- mark_missed_appointments: auto marks unconfirmed/pending appointments past 24h as missed
create or replace function mark_missed_appointments()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count int;
begin
  update appointments
  set status = 'missed'
  where status in ('pending', 'reschedule_requested')
    and starts_at < (now() - interval '24 hours');
  get diagnostics updated_count = row_count;
  return updated_count;
end;
$$;

-- 4. Storage configuration for prescriptions
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('prescriptions', 'prescriptions', false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update set public = false;

-- Storage RLS policies for prescriptions: {clinic_id}/{doctor_id}/*
create policy "Doctor prescriptions bucket select"
on storage.objects for select
using (
  bucket_id = 'prescriptions'
  and auth_clinic() is not null
  and name like (auth_clinic()::text || '/' || auth.uid()::text || '/%')
);

create policy "Doctor prescriptions bucket insert"
on storage.objects for insert
with check (
  bucket_id = 'prescriptions'
  and auth_clinic() is not null
  and name like (auth_clinic()::text || '/' || auth.uid()::text || '/%')
);

create policy "Doctor prescriptions bucket update"
on storage.objects for update
using (
  bucket_id = 'prescriptions'
  and auth_clinic() is not null
  and name like (auth_clinic()::text || '/' || auth.uid()::text || '/%')
);

create policy "Doctor prescriptions bucket delete"
on storage.objects for delete
using (
  bucket_id = 'prescriptions'
  and auth_clinic() is not null
  and name like (auth_clinic()::text || '/' || auth.uid()::text || '/%')
);
-- Migration 0003: Rate Limiting Table for Edge Functions
create table if not exists rate_limits (
  key text primary key,
  count int not null default 1,
  reset_at timestamptz not null,
  created_at timestamptz not null default now()
);

-- Index for expiring old rate limit windows
create index if not exists idx_rate_limits_reset_at on rate_limits (reset_at);

-- RLS: Service role only can read and write rate_limits
alter table rate_limits enable row level security;
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
  current_role user_role;
  result jsonb;
  request_id bigint;
  missed_count int;
begin
  current_role := auth_role();
  if current_role is null or current_role not in ('owner', 'doctor') then
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
-- CareTrack Supabase Seed Data (Demo Environment)
-- All names, contacts, and clinical records are purely synthetic demo data.

-- 1. Demo Clinics
insert into clinics (id, name, slug, timezone, settings)
values 
  ('c0000000-0000-0000-0000-000000000001', 'SmileCare Dental Clinic (Demo)', 'smilecare-demo', 'Asia/Kolkata', '{"messaging_enabled": true, "ai_enabled": true, "offline_mode_allowed": true}'::jsonb),
  ('c0000000-0000-0000-0000-000000000002', 'Apex Orthodontics (Demo Clinic 2)', 'apex-ortho-demo', 'Asia/Kolkata', '{"messaging_enabled": false}'::jsonb)
on conflict (id) do nothing;

-- 2. Auth Users (using standard Supabase auth schema)
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  -- Clinic 1 Owner
  ('u0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner.demo@caretrack.local', crypt('Password@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Dr. Ramesh Patel (Demo Owner)"}', now(), now()),
  -- Clinic 1 Doctor A
  ('u0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'doctor.a@caretrack.local', crypt('Password@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Dr. Priya Sharma (Demo Doctor A)"}', now(), now()),
  -- Clinic 1 Doctor B
  ('u0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'doctor.b@caretrack.local', crypt('Password@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Dr. Amit Verma (Demo Doctor B)"}', now(), now()),
  -- Clinic 1 Receptionist
  ('u0000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'receptionist.demo@caretrack.local', crypt('Password@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Sunita Rao (Demo Receptionist)"}', now(), now()),
  -- Clinic 2 Doctor (For RLS isolation tests)
  ('u0000000-0000-0000-0000-000000000099', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'doctor.other@caretrack.local', crypt('Password@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Dr. Suresh Kumar (Other Clinic Doctor)"}', now(), now())
on conflict (id) do nothing;

-- 3. Profiles
insert into profiles (id, clinic_id, role, full_name, active)
values
  ('u0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'owner', 'Dr. Ramesh Patel (Demo Owner)', true),
  ('u0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'doctor', 'Dr. Priya Sharma (Demo Doctor A)', true),
  ('u0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001', 'doctor', 'Dr. Amit Verma (Demo Doctor B)', true),
  ('u0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'receptionist', 'Sunita Rao (Demo Receptionist)', true),
  ('u0000000-0000-0000-0000-000000000099', 'c0000000-0000-0000-0000-000000000002', 'doctor', 'Dr. Suresh Kumar (Other Clinic Doctor)', true)
on conflict (id) do nothing;

-- 4. 10 Demo Patients
insert into patients (id, clinic_id, doctor_id, full_name, phone, email, language, messaging_consent, ai_consent, medical_notes)
values
  ('p0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000002', 'Aarav Shah (Demo Patient 1)', '+919876500001', 'aarav.shah.demo@example.com', 'en', true, true, 'Mild gingivitis, allergic to Penicillin'),
  ('p0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000002', 'Meera Joshi (Demo Patient 2)', '+919876500002', 'meera.joshi.demo@example.com', 'hi', true, true, 'Root canal treatment stage 2 completed'),
  ('p0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000002', 'Rohan Mehta (Demo Patient 3)', '+919876500003', 'rohan.mehta.demo@example.com', 'mr', true, false, 'Teeth alignment evaluation'),
  ('p0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000002', 'Ananya Iyer (Demo Patient 4)', '+919876500004', 'ananya.iyer.demo@example.com', 'en', true, true, 'Routine scaling and prophylaxis scheduled'),
  ('p0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000002', 'Vikram Malhotra (Demo Patient 5)', '+919876500005', 'vikram.m.demo@example.com', 'en', false, false, 'Opted out of digital messaging'),
  ('p0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000003', 'Neha Deshmukh (Demo Patient 6)', '+919876500006', 'neha.d.demo@example.com', 'mr', true, true, 'Sensitivity on lower right molar'),
  ('p0000000-0000-0000-0000-000000000007', 'c0000000-0000-0000-0000-000000000003', 'u0000000-0000-0000-0000-000000000003', 'Kavita Reddy (Demo Patient 7)', '+919876500007', 'kavita.reddy.demo@example.com', 'en', true, true, 'Crown placement pending'),
  ('p0000000-0000-0000-0000-000000000008', 'c0000000-0000-0000-0000-000000000003', 'u0000000-0000-0000-0000-000000000003', 'Aditya Nair (Demo Patient 8)', '+919876500008', 'aditya.nair.demo@example.com', 'en', true, false, 'Wisdom tooth extraction follow up'),
  ('p0000000-0000-0000-0000-000000000009', 'c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000003', 'Pooja Kulkarni (Demo Patient 9)', '+919876500009', 'pooja.k.demo@example.com', 'hi', true, true, 'Composite filling upper left pre-molar'),
  ('p0000000-0000-0000-0000-000000000010', 'c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000003', 'Siddharth Gupta (Demo Patient 10)', '+919876500010', 'sid.gupta.demo@example.com', 'en', true, true, 'Post-op checkup completed')
on conflict (id) do nothing;

-- 5. Prescriptions
insert into prescriptions (id, clinic_id, patient_id, doctor_id, medicines, follow_up_date, verified_at, created_at)
values
  (
    'rx000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    'p0000000-0000-0000-0000-000000000001',
    'u0000000-0000-0000-0000-000000000002',
    '[{"name": "Amoxicillin 500mg", "dosage": "1 tablet", "frequency": "Thrice daily", "duration_days": 5, "instructions": "Take after food"}, {"name": "Paracetamol 650mg", "dosage": "1 tablet", "frequency": "SOS for pain", "duration_days": 3, "instructions": "Take as needed"}]'::jsonb,
    (current_date + interval '7 days')::date,
    now() - interval '2 days',
    now() - interval '2 days'
  ),
  (
    'rx000000-0000-0000-0000-000000000002',
    'c0000000-0000-0000-0000-000000000001',
    'p0000000-0000-0000-0000-000000000002',
    'u0000000-0000-0000-0000-000000000002',
    '[{"name": "Ibuprofen 400mg", "dosage": "1 tablet", "frequency": "Twice daily", "duration_days": 3, "instructions": "After meals"}, {"name": "Chlorhexidine 0.2% Mouthwash", "dosage": "10ml", "frequency": "Twice daily", "duration_days": 10, "instructions": "Swish and spit for 30s"}]'::jsonb,
    (current_date + interval '3 days')::date,
    now() - interval '1 day',
    now() - interval '1 day'
  ),
  (
    'rx000000-0000-0000-0000-000000000003',
    'c0000000-0000-0000-0000-000000000001',
    'p0000000-0000-0000-0000-000000000006',
    'u0000000-0000-0000-0000-000000000003',
    '[{"name": "Potassium Nitrate Toothpaste", "dosage": "Pea size", "frequency": "Twice daily", "duration_days": 30, "instructions": "Brush gently"}]'::jsonb,
    (current_date + interval '14 days')::date,
    now() - interval '5 days',
    now() - interval '5 days'
  )
on conflict (id) do nothing;

-- 6. Appointments covering EVERY state:
-- pending, confirmed, reschedule_requested, rescheduled, missed, completed, cancelled
-- And dates: due today, in 3 days, in 7 days, overdue
insert into appointments (id, clinic_id, patient_id, doctor_id, starts_at, status, token_hash, token_expires_at, reminder_attempts, reminder_sent_at)
values
  -- 1. Due today, confirmed (Doctor A)
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000002', date_trunc('day', now()) + interval '10 hours', 'confirmed', encode(sha256('demo-token-1'::bytea), 'hex'), now() + interval '1 day', 1, now() - interval '20 hours'),

  -- 2. Due today, pending reminder (Doctor A)
  ('a0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000002', 'u0000000-0000-0000-0000-000000000002', date_trunc('day', now()) + interval '14 hours', 'pending', encode(sha256('demo-token-2'::bytea), 'hex'), now() + interval '1 day', 0, null),

  -- 3. In 3 days, confirmed (Doctor A)
  ('a0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000003', 'u0000000-0000-0000-0000-000000000002', date_trunc('day', now()) + interval '3 days 11 hours', 'confirmed', encode(sha256('demo-token-3'::bytea), 'hex'), now() + interval '4 days', 0, null),

  -- 4. In 7 days, pending (Doctor A)
  ('a0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000004', 'u0000000-0000-0000-0000-000000000002', date_trunc('day', now()) + interval '7 days 15 hours', 'pending', encode(sha256('demo-token-4'::bytea), 'hex'), now() + interval '8 days', 0, null),

  -- 5. Overdue (2 hours ago, still pending) (Doctor A)
  ('a0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000005', 'u0000000-0000-0000-0000-000000000002', now() - interval '2 hours', 'pending', encode(sha256('demo-token-5'::bytea), 'hex'), now() + interval '12 hours', 1, now() - interval '24 hours'),

  -- 6. Reschedule requested (tomorrow) (Doctor A)
  ('a0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000002', date_trunc('day', now()) + interval '1 day 16 hours', 'reschedule_requested', encode(sha256('demo-token-6'::bytea), 'hex'), now() + interval '2 days', 1, now() - interval '10 hours'),

  -- 7. Rescheduled state (Doctor B)
  ('a0000000-0000-0000-0000-000000000007', 'c0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000006', 'u0000000-0000-0000-0000-000000000003', date_trunc('day', now()) + interval '2 days 10 hours', 'rescheduled', encode(sha256('demo-token-7'::bytea), 'hex'), now() + interval '3 days', 0, null),

  -- 8. Missed appointment (>24h past start) (Doctor B)
  ('a0000000-0000-0000-0000-000000000008', 'c0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000007', 'u0000000-0000-0000-0000-000000000003', now() - interval '30 hours', 'missed', encode(sha256('demo-token-8'::bytea), 'hex'), now() - interval '10 hours', 1, now() - interval '50 hours'),

  -- 9. Completed appointment (Doctor B)
  ('a0000000-0000-0000-0000-000000000009', 'c0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000008', 'u0000000-0000-0000-0000-000000000003', now() - interval '3 days', 'completed', encode(sha256('demo-token-9'::bytea), 'hex'), now() - interval '2 days', 1, now() - interval '4 days'),

  -- 10. Cancelled appointment (Doctor B)
  ('a0000000-0000-0000-0000-000000000010', 'c0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000009', 'u0000000-0000-0000-0000-000000000003', now() - interval '1 day', 'cancelled', encode(sha256('demo-token-10'::bytea), 'hex'), now() - interval '12 hours', 1, now() - interval '2 days')
on conflict (id) do nothing;

-- 7. Availability Schedules (Doctors working Mon-Sat 09:00 - 18:00, 1h lunch break)
insert into availability (clinic_id, doctor_id, day_of_week, start_time, end_time, slot_duration_minutes, breaks)
values
  -- Doctor A: Mon through Fri
  ('c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000002', 1, '09:00:00', '18:00:00', 30, '[{"start": "13:00", "end": "14:00"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000002', 2, '09:00:00', '18:00:00', 30, '[{"start": "13:00", "end": "14:00"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000002', 3, '09:00:00', '18:00:00', 30, '[{"start": "13:00", "end": "14:00"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000002', 4, '09:00:00', '18:00:00', 30, '[{"start": "13:00", "end": "14:00"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000002', 5, '09:00:00', '18:00:00', 30, '[{"start": "13:00", "end": "14:00"}]'::jsonb),
  -- Doctor B: Mon through Fri
  ('c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000003', 1, '10:00:00', '19:00:00', 30, '[{"start": "13:30", "end": "14:30"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000003', 2, '10:00:00', '19:00:00', 30, '[{"start": "13:30", "end": "14:30"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000003', 3, '10:00:00', '19:00:00', 30, '[{"start": "13:30", "end": "14:30"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000003', 4, '10:00:00', '19:00:00', 30, '[{"start": "13:30", "end": "14:30"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000003', 5, '10:00:00', '19:00:00', 30, '[{"start": "13:30", "end": "14:30"}]'::jsonb)
on conflict do nothing;

-- 8. Clinic Holidays
insert into clinic_holidays (clinic_id, holiday_date, name)
values
  ('c0000000-0000-0000-0000-000000000001', (current_date + interval '20 days')::date, 'Diwali Festival (Demo Holiday)')
on conflict (clinic_id, holiday_date) do nothing;

-- 9. Treatment Plan Templates & Plans
insert into treatment_plan_templates (id, clinic_id, doctor_id, title, description, stages)
values
  (
    't0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    'u0000000-0000-0000-0000-000000000002',
    'Root Canal Treatment (RCT) Multi-stage',
    'Standard 3-step endodontic treatment protocol',
    '[{"order": 1, "name": "Pulp Extirpation & Biomechanical Prep", "interval_days": 0}, {"order": 2, "name": "Canal Disinfection & Temporary Dressing", "interval_days": 7}, {"order": 3, "name": "Obturation & Permanent Core", "interval_days": 7}]'::jsonb
  )
on conflict (id) do nothing;

insert into treatment_plans (id, clinic_id, patient_id, doctor_id, template_id, title, status)
values
  (
    'tp000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    'p0000000-0000-0000-0000-000000000002',
    'u0000000-0000-0000-0000-000000000002',
    't0000000-0000-0000-0000-000000000001',
    'Tooth #16 RCT Plan',
    'active'
  )
on conflict (id) do nothing;

insert into plan_stages (clinic_id, plan_id, stage_order, name, interval_days_from_previous, status, completed_at)
values
  ('c0000000-0000-0000-0000-000000000001', 'tp000000-0000-0000-0000-000000000001', 1, 'Pulp Extirpation & Biomechanical Prep', 0, 'completed', now() - interval '8 days'),
  ('c0000000-0000-0000-0000-000000000001', 'tp000000-0000-0000-0000-000000000001', 2, 'Canal Disinfection & Temporary Dressing', 7, 'completed', now() - interval '1 day'),
  ('c0000000-0000-0000-0000-000000000001', 'tp000000-0000-0000-0000-000000000001', 3, 'Obturation & Permanent Core', 7, 'pending', null)
on conflict do nothing;

-- 10. Sample WhatsApp Conversation & Messages
insert into conversations (id, clinic_id, patient_id, phone, status, is_urgent, last_message_at)
values
  ('cnv00000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000001', '+919876500001', 'open', false, now() - interval '10 minutes')
on conflict (id) do nothing;

insert into messages (clinic_id, conversation_id, sender_type, body, direction, channel, is_urgent)
values
  ('c0000000-0000-0000-0000-000000000001', 'cnv00000-0000-0000-0000-000000000001', 'system', 'Hello Aarav Shah, reminder for your appointment today at 10:00 AM.', 'outbound', 'whatsapp', false),
  ('c0000000-0000-0000-0000-000000000001', 'cnv00000-0000-0000-0000-000000000001', 'patient', '1', 'inbound', 'whatsapp', false)
on conflict do nothing;

-- 11. Consents
insert into consents (clinic_id, patient_id, type, granted, method, notes)
values
  ('c0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000001', 'messaging', true, 'in_person', 'Signed registration form'),
  ('c0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000001', 'ai', true, 'in_person', 'Consented to AI prescription assistance'),
  ('c0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000002', 'messaging', true, 'whatsapp_opt_in', 'Consented via WhatsApp handshake')
on conflict do nothing;
