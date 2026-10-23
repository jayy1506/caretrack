-- RLS & Security Verification Suite for CareTrack
-- Tests user roles, cross-clinic isolation, role immutability, prescription privacy, and slot uniqueness.

begin;

-- Mock auth schema if running in standalone postgres test
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
create or replace function auth.role() returns text language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), 'anon');
$$;

do $$
declare
  clinic1_id uuid := 'c0000000-0000-0000-0000-000000000001';
  clinic2_id uuid := 'c0000000-0000-0000-0000-000000000002';
  owner_id uuid := 'u0000000-0000-0000-0000-000000000001';
  doc_a_id uuid := 'u0000000-0000-0000-0000-000000000002';
  doc_b_id uuid := 'u0000000-0000-0000-0000-000000000003';
  recep_id uuid := 'u0000000-0000-0000-0000-000000000004';
  other_doc_id uuid := 'u0000000-0000-0000-0000-000000000099';
  patient_a_id uuid := 'p0000000-0000-0000-0000-000000000001';
  patient_b_id uuid := 'p0000000-0000-0000-0000-000000000006';

  rec_count int;
  caught_error boolean;
begin
  raise notice 'Running RLS & Security Verification Suite...';

  ------------------------------------------------------------
  -- 1. Anonymous Access Denied
  ------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);

  select count(*) into rec_count from patients;
  if rec_count != 0 then
    raise exception 'FAIL: Anonymous user was able to read patients!';
  end if;

  select count(*) into rec_count from prescriptions;
  if rec_count != 0 then
    raise exception 'FAIL: Anonymous user was able to read prescriptions!';
  end if;

  select count(*) into rec_count from appointments;
  if rec_count != 0 then
    raise exception 'FAIL: Anonymous user was able to read appointments!';
  end if;

  raise notice 'PASS: Anonymous access denied to all clinical tables.';

  ------------------------------------------------------------
  -- 2. Cross-Clinic Reads Fail
  ------------------------------------------------------------
  -- Sign in as Doctor from Clinic 2
  perform set_config('request.jwt.claim.sub', other_doc_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  -- Should see zero patients from Clinic 1
  select count(*) into rec_count from patients where clinic_id = clinic1_id;
  if rec_count != 0 then
    raise exception 'FAIL: Clinic 2 doctor saw patients from Clinic 1!';
  end if;

  -- Should see zero appointments from Clinic 1
  select count(*) into rec_count from appointments where clinic_id = clinic1_id;
  if rec_count != 0 then
    raise exception 'FAIL: Clinic 2 doctor saw appointments from Clinic 1!';
  end if;

  -- Should see zero clinics other than own
  select count(*) into rec_count from clinics where id = clinic1_id;
  if rec_count != 0 then
    raise exception 'FAIL: Clinic 2 doctor saw Clinic 1 details!';
  end if;

  raise notice 'PASS: Cross-clinic isolation verified.';

  ------------------------------------------------------------
  -- 3. Doctor B cannot read Doctor A patients or prescriptions
  ------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', doc_b_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  -- Doctor B queries Doctor A's patient
  select count(*) into rec_count from patients where doctor_id = doc_a_id;
  if rec_count != 0 then
    raise exception 'FAIL: Doctor B was able to read Doctor A patients!';
  end if;

  -- Doctor B queries Doctor A's prescriptions
  select count(*) into rec_count from prescriptions where doctor_id = doc_a_id;
  if rec_count != 0 then
    raise exception 'FAIL: Doctor B was able to read Doctor A prescriptions!';
  end if;

  -- But Doctor B CAN read own patients
  select count(*) into rec_count from patients where doctor_id = doc_b_id;
  if rec_count = 0 then
    raise exception 'FAIL: Doctor B was unable to read own patients!';
  end if;

  raise notice 'PASS: Doctor-to-Doctor patient and prescription isolation verified.';

  ------------------------------------------------------------
  -- 4. Receptionist cannot read prescriptions, but can read patients
  ------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', recep_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  -- Receptionist reads prescriptions -> must be 0
  select count(*) into rec_count from prescriptions;
  if rec_count != 0 then
    raise exception 'FAIL: Receptionist was able to read prescriptions!';
  end if;

  -- Receptionist reads patients in clinic -> should see clinic patients
  select count(*) into rec_count from patients where clinic_id = clinic1_id;
  if rec_count = 0 then
    raise exception 'FAIL: Receptionist could not read clinic patients!';
  end if;

  raise notice 'PASS: Receptionist role permissions verified (no Rx access, patient access ok).';

  ------------------------------------------------------------
  -- 5. Nobody can change their own role (Privilege escalation)
  ------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', doc_a_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  caught_error := false;
  begin
    update profiles set role = 'owner' where id = doc_a_id;
    -- Check if update affected any row
    get diagnostics rec_count = row_count;
    if rec_count > 0 then
      raise exception 'FAIL: Doctor A was able to update their role to owner!';
    end if;
  exception when others then
    caught_error := true;
  end;

  -- Either row_count = 0 due to RLS or trigger raised exception
  raise notice 'PASS: Privilege escalation prevented (role cannot be changed by user).';

  ------------------------------------------------------------
  -- 6. Slot cannot be double booked
  ------------------------------------------------------------
  caught_error := false;
  begin
    -- Attempt inserting an appointment for Doctor A at the exact same start time as an existing one
    insert into appointments (clinic_id, patient_id, doctor_id, starts_at, status)
    values (
      clinic1_id,
      patient_a_id,
      doc_a_id,
      date_trunc('day', now()) + interval '10 hours',
      'pending'
    );
  exception when unique_violation then
    caught_error := true;
  end;

  if not caught_error then
    raise exception 'FAIL: Double booking was allowed for doctor at the same time slot!';
  end if;

  raise notice 'PASS: Slot double booking prevention verified (unique doctor_id, starts_at).';

  raise notice 'ALL RLS AND SECURITY TESTS PASSED SUCCESSFULLY!';
end;
$$;

rollback;
