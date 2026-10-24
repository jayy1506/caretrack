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
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner.demo@caretrack.local', crypt('Password@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Dr. Ramesh Patel (Demo Owner)"}', now(), now()),
  -- Clinic 1 Doctor A
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'doctor.a@caretrack.local', crypt('Password@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Dr. Priya Sharma (Demo Doctor A)"}', now(), now()),
  -- Clinic 1 Doctor B
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'doctor.b@caretrack.local', crypt('Password@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Dr. Amit Verma (Demo Doctor B)"}', now(), now()),
  -- Clinic 1 Receptionist
  ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'receptionist.demo@caretrack.local', crypt('Password@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Sunita Rao (Demo Receptionist)"}', now(), now()),
  -- Clinic 2 Doctor (For RLS isolation tests)
  ('10000000-0000-0000-0000-000000000099', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'doctor.other@caretrack.local', crypt('Password@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Dr. Suresh Kumar (Other Clinic Doctor)"}', now(), now())
on conflict (id) do nothing;

-- 3. Profiles
insert into profiles (id, clinic_id, role, full_name, active)
values
  ('10000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'owner', 'Dr. Ramesh Patel (Demo Owner)', true),
  ('10000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'doctor', 'Dr. Priya Sharma (Demo Doctor A)', true),
  ('10000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001', 'doctor', 'Dr. Amit Verma (Demo Doctor B)', true),
  ('10000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'receptionist', 'Sunita Rao (Demo Receptionist)', true),
  ('10000000-0000-0000-0000-000000000099', 'c0000000-0000-0000-0000-000000000002', 'doctor', 'Dr. Suresh Kumar (Other Clinic Doctor)', true)
on conflict (id) do nothing;

-- 4. 10 Demo Patients
insert into patients (id, clinic_id, doctor_id, full_name, phone, email, language, messaging_consent, ai_consent, medical_notes)
values
  ('20000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'Aarav Shah (Demo Patient 1)', '+919876500001', 'aarav.shah.demo@example.com', 'en', true, true, 'Mild gingivitis, allergic to Penicillin'),
  ('20000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'Meera Joshi (Demo Patient 2)', '+919876500002', 'meera.joshi.demo@example.com', 'hi', true, true, 'Root canal treatment stage 2 completed'),
  ('20000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'Rohan Mehta (Demo Patient 3)', '+919876500003', 'rohan.mehta.demo@example.com', 'mr', true, false, 'Teeth alignment evaluation'),
  ('20000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'Ananya Iyer (Demo Patient 4)', '+919876500004', 'ananya.iyer.demo@example.com', 'en', true, true, 'Routine scaling and prophylaxis scheduled'),
  ('20000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'Vikram Malhotra (Demo Patient 5)', '+919876500005', 'vikram.m.demo@example.com', 'en', false, false, 'Opted out of digital messaging'),
  ('20000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 'Neha Deshmukh (Demo Patient 6)', '+919876500006', 'neha.d.demo@example.com', 'mr', true, true, 'Sensitivity on lower right molar'),
  ('20000000-0000-0000-0000-000000000007', 'c0000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', 'Kavita Reddy (Demo Patient 7)', '+919876500007', 'kavita.reddy.demo@example.com', 'en', true, true, 'Crown placement pending'),
  ('20000000-0000-0000-0000-000000000008', 'c0000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', 'Aditya Nair (Demo Patient 8)', '+919876500008', 'aditya.nair.demo@example.com', 'en', true, false, 'Wisdom tooth extraction follow up'),
  ('20000000-0000-0000-0000-000000000009', 'c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 'Pooja Kulkarni (Demo Patient 9)', '+919876500009', 'pooja.k.demo@example.com', 'hi', true, true, 'Composite filling upper left pre-molar'),
  ('20000000-0000-0000-0000-000000000010', 'c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 'Siddharth Gupta (Demo Patient 10)', '+919876500010', 'sid.gupta.demo@example.com', 'en', true, true, 'Post-op checkup completed')
on conflict (id) do nothing;

-- 5. Prescriptions
insert into prescriptions (id, clinic_id, patient_id, doctor_id, medicines, follow_up_date, verified_at, created_at)
values
  (
    '30000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000002',
    '[{"name": "Amoxicillin 500mg", "dosage": "1 tablet", "frequency": "Thrice daily", "duration_days": 5, "instructions": "Take after food"}, {"name": "Paracetamol 650mg", "dosage": "1 tablet", "frequency": "SOS for pain", "duration_days": 3, "instructions": "Take as needed"}]'::jsonb,
    (current_date + interval '7 days')::date,
    now() - interval '2 days',
    now() - interval '2 days'
  ),
  (
    '30000000-0000-0000-0000-000000000002',
    'c0000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000002',
    '[{"name": "Ibuprofen 400mg", "dosage": "1 tablet", "frequency": "Twice daily", "duration_days": 3, "instructions": "After meals"}, {"name": "Chlorhexidine 0.2% Mouthwash", "dosage": "10ml", "frequency": "Twice daily", "duration_days": 10, "instructions": "Swish and spit for 30s"}]'::jsonb,
    (current_date + interval '3 days')::date,
    now() - interval '1 day',
    now() - interval '1 day'
  ),
  (
    '30000000-0000-0000-0000-000000000003',
    'c0000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000006',
    '10000000-0000-0000-0000-000000000003',
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
  ('40000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', date_trunc('day', now()) + interval '10 hours', 'confirmed', encode(sha256('demo-token-1'::bytea), 'hex'), now() + interval '1 day', 1, now() - interval '20 hours'),

  -- 2. Due today, pending reminder (Doctor A)
  ('40000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', date_trunc('day', now()) + interval '14 hours', 'pending', encode(sha256('demo-token-2'::bytea), 'hex'), now() + interval '1 day', 0, null),

  -- 3. In 3 days, confirmed (Doctor A)
  ('40000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', date_trunc('day', now()) + interval '3 days 11 hours', 'confirmed', encode(sha256('demo-token-3'::bytea), 'hex'), now() + interval '4 days', 0, null),

  -- 4. In 7 days, pending (Doctor A)
  ('40000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002', date_trunc('day', now()) + interval '7 days 15 hours', 'pending', encode(sha256('demo-token-4'::bytea), 'hex'), now() + interval '8 days', 0, null),

  -- 5. Overdue (2 hours ago, still pending) (Doctor A)
  ('40000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000002', now() - interval '2 hours', 'pending', encode(sha256('demo-token-5'::bytea), 'hex'), now() + interval '12 hours', 1, now() - interval '24 hours'),

  -- 6. Reschedule requested (tomorrow) (Doctor A)
  ('40000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', date_trunc('day', now()) + interval '1 day 16 hours', 'reschedule_requested', encode(sha256('demo-token-6'::bytea), 'hex'), now() + interval '2 days', 1, now() - interval '10 hours'),

  -- 7. Rescheduled state (Doctor B)
  ('40000000-0000-0000-0000-000000000007', 'c0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000003', date_trunc('day', now()) + interval '2 days 10 hours', 'rescheduled', encode(sha256('demo-token-7'::bytea), 'hex'), now() + interval '3 days', 0, null),

  -- 8. Missed appointment (>24h past start) (Doctor B)
  ('40000000-0000-0000-0000-000000000008', 'c0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000003', now() - interval '30 hours', 'missed', encode(sha256('demo-token-8'::bytea), 'hex'), now() - interval '10 hours', 1, now() - interval '50 hours'),

  -- 9. Completed appointment (Doctor B)
  ('40000000-0000-0000-0000-000000000009', 'c0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000003', now() - interval '3 days', 'completed', encode(sha256('demo-token-9'::bytea), 'hex'), now() - interval '2 days', 1, now() - interval '4 days'),

  -- 10. Cancelled appointment (Doctor B)
  ('40000000-0000-0000-0000-000000000010', 'c0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-000000000003', now() - interval '1 day', 'cancelled', encode(sha256('demo-token-10'::bytea), 'hex'), now() - interval '12 hours', 1, now() - interval '2 days')
on conflict (id) do nothing;

-- 7. Availability Schedules (Doctors working Mon-Sat 09:00 - 18:00, 1h lunch break)
insert into availability (clinic_id, doctor_id, day_of_week, start_time, end_time, slot_duration_minutes, breaks)
values
  -- Doctor A: Mon through Fri
  ('c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 1, '09:00:00', '18:00:00', 30, '[{"start": "13:00", "end": "14:00"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 2, '09:00:00', '18:00:00', 30, '[{"start": "13:00", "end": "14:00"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 3, '09:00:00', '18:00:00', 30, '[{"start": "13:00", "end": "14:00"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 4, '09:00:00', '18:00:00', 30, '[{"start": "13:00", "end": "14:00"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 5, '09:00:00', '18:00:00', 30, '[{"start": "13:00", "end": "14:00"}]'::jsonb),
  -- Doctor B: Mon through Fri
  ('c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 1, '10:00:00', '19:00:00', 30, '[{"start": "13:30", "end": "14:30"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 2, '10:00:00', '19:00:00', 30, '[{"start": "13:30", "end": "14:30"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 3, '10:00:00', '19:00:00', 30, '[{"start": "13:30", "end": "14:30"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 4, '10:00:00', '19:00:00', 30, '[{"start": "13:30", "end": "14:30"}]'::jsonb),
  ('c0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 5, '10:00:00', '19:00:00', 30, '[{"start": "13:30", "end": "14:30"}]'::jsonb)
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
    '50000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000002',
    'Root Canal Treatment (RCT) Multi-stage',
    'Standard 3-step endodontic treatment protocol',
    '[{"order": 1, "name": "Pulp Extirpation & Biomechanical Prep", "interval_days": 0}, {"order": 2, "name": "Canal Disinfection & Temporary Dressing", "interval_days": 7}, {"order": 3, "name": "Obturation & Permanent Core", "interval_days": 7}]'::jsonb
  )
on conflict (id) do nothing;

insert into treatment_plans (id, clinic_id, patient_id, doctor_id, template_id, title, status)
values
  (
    '60000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000002',
    '50000000-0000-0000-0000-000000000001',
    'Tooth #16 RCT Plan',
    'active'
  )
on conflict (id) do nothing;

insert into plan_stages (clinic_id, plan_id, stage_order, name, interval_days_from_previous, status, completed_at)
values
  ('c0000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', 1, 'Pulp Extirpation & Biomechanical Prep', 0, 'completed', now() - interval '8 days'),
  ('c0000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', 2, 'Canal Disinfection & Temporary Dressing', 7, 'completed', now() - interval '1 day'),
  ('c0000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', 3, 'Obturation & Permanent Core', 7, 'pending', null)
on conflict do nothing;

-- 10. Sample WhatsApp Conversation & Messages
insert into conversations (id, clinic_id, patient_id, phone, status, is_urgent, last_message_at)
values
  ('70000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '+919876500001', 'open', false, now() - interval '10 minutes')
on conflict (id) do nothing;

insert into messages (clinic_id, conversation_id, sender_type, body, direction, channel, is_urgent)
values
  ('c0000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', 'system', 'Hello Aarav Shah, reminder for your appointment today at 10:00 AM.', 'outbound', 'whatsapp', false),
  ('c0000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', 'patient', '1', 'inbound', 'whatsapp', false)
on conflict do nothing;

-- 11. Consents
insert into consents (clinic_id, patient_id, type, granted, method, notes)
values
  ('c0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'messaging', true, 'in_person', 'Signed registration form'),
  ('c0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'ai', true, 'in_person', 'Consented to AI prescription assistance'),
  ('c0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', 'messaging', true, 'whatsapp_opt_in', 'Consented via WhatsApp handshake')
on conflict do nothing;
