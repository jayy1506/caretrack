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

alter table clinics, profiles, patients, prescriptions, appointments, notifications, audit_logs enable row level security;

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
