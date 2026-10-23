# Supabase Local Development & Deployment Guide for CareTrack

CareTrack runs on Supabase (PostgreSQL, Auth, Storage, Edge Functions, pg_cron).

## 1. Prerequisites
- [Supabase CLI](https://supabase.com/docs/guides/cli): `npm install -g supabase` or `npx supabase`
- [Docker Desktop](https://www.docker.com/) (for running the local Supabase stack)
- [Deno](https://deno.land/) (v2+ for Edge Functions and Deno test runner)
- [Flutter SDK](https://docs.flutter.dev/) (v3.19+)

---

## 2. Local Supabase Setup

### Start the Local Stack
Start Docker Desktop, then in the project root:
```bash
supabase start
```
This boots Postgres, Supabase Studio, Auth, Storage, and Edge Functions gateway.
At the end of the start command, the CLI will output:
- **API URL:** `http://127.0.0.1:54321`
- **GraphQL URL:** `http://127.0.0.1:54321/graphql/v1`
- **Inbucket (Email testing):** `http://127.0.0.1:54324`
- **Studio URL:** `http://127.0.0.1:54323`
- **anon key:** `eyJhbGciOi...`
- **service_role key:** `eyJhbGciOi...`

### Reset Database & Seed Demo Data
To re-apply all migrations (`supabase/migrations/`) and load sample data (`supabase/seed.sql`):
```bash
supabase db reset
```

The seed data provisions:
- 1 Demo Clinic (`SmileCare Dental Clinic`) + 1 Auxiliary Clinic for isolation testing
- 1 Owner account: `owner.demo@caretrack.local` / `Password@123`
- 2 Doctor accounts: `doctor.a@caretrack.local`, `doctor.b@caretrack.local` / `Password@123`
- 1 Receptionist account: `receptionist.demo@caretrack.local` / `Password@123`
- 10 synthetic demo patients
- Clinical appointments covering all statuses (`pending`, `confirmed`, `reschedule_requested`, `rescheduled`, `missed`, `completed`, `cancelled`) and time horizons (`today`, `in 3 days`, `in 7 days`, `overdue`)
- Treatment plan templates, availability schedules, and holiday calendars

---

## 3. Running RLS & Security Tests

Run the Deno security test suite (mirrors and verifies all Postgres RLS policies and constraints):
```bash
deno test supabase/tests/rls_test.ts
```

Run the SQL RLS verification suite inside PostgreSQL:
```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/tests/rls_test.sql
```

---

## 4. Connecting the CareTrack Flutter App

### Local Development
To launch the Flutter app against the local Supabase container:

**Desktop / Web / iOS Simulator:**
```bash
cd caretrack_app
flutter run \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<LOCAL_ANON_KEY>
```

**Android Emulator (requires 10.0.2.2 instead of 127.0.0.1):**
```bash
cd caretrack_app
flutter run \
  --dart-define=SUPABASE_URL=http://10.0.2.2:54321 \
  --dart-define=SUPABASE_ANON_KEY=<LOCAL_ANON_KEY>
```

---

## 5. Hosted Supabase Deployment (Free Tier)

1. Create a free project on [database.new](https://database.new) (No credit card required).
2. Link your local project:
   ```bash
   supabase login
   supabase link --project-ref <YOUR_PROJECT_REF>
   ```
3. Push migrations and seed data:
   ```bash
   supabase db push
   ```
4. Configure required secrets:
   ```bash
   supabase secrets set \
     GEMINI_API_KEY="<your-gemini-key>" \
     GEMINI_MODEL="gemini-2.0-flash" \
     BREVO_API_KEY="<your-brevo-key>" \
     MESSAGING_PROVIDER="whatsapp" \
     WHATSAPP_PHONE_NUMBER_ID="<meta-phone-id>" \
     WHATSAPP_ACCESS_TOKEN="<meta-access-token>" \
     WHATSAPP_APP_SECRET="<meta-app-secret>" \
     WHATSAPP_VERIFY_TOKEN="<meta-webhook-verify-token>" \
     BASE_APP_URL="https://caretrack.yourdomain.com" \
     JOB_SECRET="<crypto-random-32-chars>"
   ```
5. Deploy Edge Functions:
   ```bash
   supabase functions deploy
   ```
6. Run the Flutter app with hosted credentials:
   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://<YOUR_PROJECT_REF>.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=<HOSTED_ANON_KEY>
   ```
