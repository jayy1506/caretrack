# Walkthrough: CareTrack — Supabase Migration & Clinical Platform

We have successfully migrated **CareTrack** from Firebase to **Supabase** (PostgreSQL 15+, Supabase Auth, Storage, Edge Functions in Deno, and `pg_cron`).

---

## 1. Repository Structure After Migration

```
dental/
├── .github/workflows/ci.yml                # CI/CD: Flutter analyze & test, Deno check & test
├── supabase/                               # Pure Supabase Architecture
│   ├── config.toml                         # Supabase local stack configuration
│   ├── seed.sql                            # Multi-clinic seed data, test accounts, appointments
│   ├── migrations/
│   │   ├── 0001_init.sql                   # Tables, RLS policies, staff roles & tenant isolation
│   │   ├── 0002_extensions_and_features.sql# Availability schedules, holidays, treatment plans
│   │   ├── 0003_rate_limits.sql            # Anti-abuse IP rate limiting tables
│   │   └── 0004_cron_jobs.sql              # pg_cron & pg_net automated dispatcher & Vault
│   ├── functions/                          # 15 Deno v2 TypeScript Edge Functions
│   │   ├── _shared/                        # Zod schemas, clients, audit logging, CORS, masked logger
│   │   ├── book-slot/                      # Public online slot booking with rate limit & tokens
│   │   ├── confirm-appointment/            # Patient one-tap confirmation
│   │   ├── create-staff/                   # Multi-clinic staff role creation (owner-only)
│   │   ├── extract-prescription/           # Gemini 2.0 Flash structured prescription parsing
│   │   ├── get-slots/                      # Working-hour, holiday, and break aware slot generator
│   │   ├── medication-reminders/           # Dose reminders & adherence tracker
│   │   ├── patient-data-tools/             # DPDP Data Subject Export & Right-to-Erasure
│   │   ├── post-treatment-care/            # pg_cron follow-up dispatcher with X-Job-Secret
│   │   ├── recall-list/                    # Inactive recall queue suggestions
│   │   ├── retry-notification/             # Dead-letter queue notification retry
│   │   ├── send-direct-message/            # Two-way clinic messaging (WhatsApp / Email / Telegram)
│   │   ├── send-notifications/             # Multi-channel notification engine
│   │   ├── send-recall/                    # Clinical recall campaign sender
│   │   ├── treatment-plans/                # Multi-stage dental treatment pipeline
│   │   └── whatsapp-webhook/               # Meta webhook with emergency triage engine
│   └── tests/
│       ├── functions_test.ts               # 16 Deno unit & integration tests
│       ├── rls_test.ts                     # Deno RLS multi-tenant security verification
│       └── rls_test.sql                    # SQL RLS policy tests
└── caretrack_app/                          # Flutter Mobile & Desktop Application
    ├── pubspec.yaml                        # Uses supabase_flutter (all firebase_* removed)
    ├── lib/
    │   ├── main.dart                       # Supabase client init, Auth Gate, MultiProvider
    │   ├── core/
    │   │   ├── supabase_config.dart        # URL/AnonKey validation & timezone helpers
    │   │   ├── theme/app_theme.dart        # Material 3 clinical tokens & Plus Jakarta Sans
    │   │   └── widgets/
    │   │       ├── bottom_nav_pill.dart    # Floating pill navigation for mobile
    │   │       ├── status_badge.dart       # Redesigned 16px pill badges with borders
    │   │       └── offline_banner.dart     # Offline connectivity banner
    │   ├── models/                         # Snake_case Postgres mapping with DateTime parsing
    │   ├── services/                       # Pure Supabase query services with offline cache
    │   └── screens/                        # Responsive desktop sidebar / mobile shell
    └── test/
        ├── phase5_frontend_test.dart       # M3 theme, status badge, BottomNavPill tests
        ├── phase6_widget_test.dart         # Risk chips & safety banner tests
        └── phase7_widget_test.dart         # CounterTile, stepper & golden theming tests
```

---

## 2. Completed Migration Phases

1. **Phase 1: Database & Security (PostgreSQL + RLS)**
   - Schema defined for multi-clinic tenants (`clinics`, `profiles`, `patients`, `appointments`, `prescriptions`, `treatment_plans`, `audit_logs`).
   - RLS strictly enforced on every table. Cross-clinic access is blocked at the database kernel level.
   - Comprehensive SQL & Deno RLS tests passing.

2. **Phase 2: Edge Functions Suite (Deno v2 + Zod)**
   - 15 Edge Functions replacing legacy Firebase Cloud Functions.
   - Zod schema validation, generic error messages for end-users, and PII masking (`+91******1234`).
   - Provider abstraction: Meta WhatsApp Cloud API, Telegram Bot, Brevo/SMTP Email.

3. **Phase 3: Scheduled Jobs & Vault (`pg_cron` + `pg_net`)**
   - Configurable reminder window (`23h - 25h`) and post-care follow-up dispatcher (`claim_due_post_care` with `SKIP LOCKED`).
   - `post-treatment-care` Edge Function secured via `X-Job-Secret` cryptographic verification.
   - Manual trigger RPC `run_scheduled_job_manual(job_name)` restricted to `owner` and `doctor`.

4. **Phase 4: Flutter Data Layer Migration**
   - Removed all `firebase_*` packages and integrated `supabase_flutter`.
   - Converted all models and services to Supabase PostgreSQL RPCs, Realtime streams, and Edge Functions.
   - Offline local caching for dashboard counters and appointments.

5. **Phase 5: Frontend Redesign & Material 3 Theming**
   - Full Material 3 theming with clinical palette: Deep Navy (`#0F2A47`), Clinical Teal (`#0F766E`), Mint Accent (`#2DD4BF`), Background Grey (`#F3F6FA`).
   - Redesigned pill StatusBadges with 16px radius and color-matched borders.
   - Floating `BottomNavPill` for mobile screens (< 900px) and fixed responsive sidebar for desktop (>= 900px).
   - Light and Dark mode verified with widget tests.

6. **Phase 6: Compliance, Documentation, Cleanup & Deployment**
   - DPDP Act 2023 compliance with Data Subject Access Request export and Right-to-Erasure tools.
   - Firebase completely purged (`firebase.json`, `.firebaserc`, `firestore.rules`, `storage.rules`, `functions/`, `firebase_options.dart`).
   - Added automated GitHub Actions CI workflow for Flutter and Deno.
   - Overhauled README with architecture diagrams and free-tier deployment guide.
