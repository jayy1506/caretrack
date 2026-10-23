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
