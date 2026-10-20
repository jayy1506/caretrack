# Walkthrough: CareTrack — Doctor Follow-up & Patient Reminder Android App

We have architected and implemented **CareTrack**, a robust, real-world clinic follow-up and patient reminder mobile application and backend engine.

---

## 1. What Was Built

```
dental/
├── firebase.json                           # Firebase deployment & emulators configuration
├── firestore.rules                         # Security rules with doctor data isolation & admin guards
├── storage.rules                           # Storage rules for prescription documents
├── firestore.indexes.json                  # Firestore query composite indexes
├── functions/                              # Cloud Functions 2nd Gen (Node.js/TypeScript)
│   ├── package.json
│   ├── tsconfig.json
│   ├── .env.example
│   └── src/
│       ├── config/index.ts                 # Firebase Admin & env config
│       ├── types/index.ts                  # Shared domain types & schemas
│       ├── services/
│       │   ├── followUpService.ts          # Deterministic calendar math (+3m, 15d, 1m, 6m, custom)
│       │   ├── geminiService.ts            # Gemini 1.5 Flash structured prescription extractor
│       │   ├── emailService.ts             # Gmail SMTP (Nodemailer) & clinical HTML templates
│       │   ├── messagingService.ts         # WhatsApp Cloud API & Telegram provider abstraction
│       │   ├── pushService.ts              # Firebase Cloud Messaging dispatcher
│       │   └── notificationService.ts      # Multi-channel orchestrator + Firestore logger
│       ├── auth/index.ts                   # createDoctor & toggleDoctorStatus callables
│       ├── patients/index.ts               # sendPatientRegistrationNotification callable
│       ├── prescriptions/index.ts          # extractPrescriptionData callable
│       ├── appointments/index.ts           # confirmAppointmentWeb & sendAppointmentConfirmation
│       ├── scheduled/reminderEngine.ts     # scheduledReminderEngine cron & triggerDemoReminderCheck
│       └── index.ts                        # Main Cloud Functions export
└── caretrack_app/                          # Android Mobile Application (Flutter & Dart)
    ├── pubspec.yaml
    ├── android/
    │   └── app/src/main/AndroidManifest.xml
    └── lib/
        ├── main.dart                       # Entry point, Firebase init, Auth Gate, MultiProvider
        ├── core/
        │   ├── theme/app_theme.dart        # Navy/Slate clinical theme & design system
        │   ├── utils/date_formatter.dart   # Date formatting & follow-up calculator
        │   └── widgets/
        │       ├── custom_button.dart      # Clinical buttons with loading states
        │       ├── custom_text_field.dart  # Form inputs
        │       ├── status_badge.dart       # Confirmed, Pending, Missed, Overdue badges
        │       ├── empty_state_view.dart   # Clean empty states with action triggers
        │       └── offline_banner.dart     # Offline network warning banner
        ├── models/
        │   ├── user_model.dart             # Admin / Doctor user profile & role claims
        │   ├── patient_model.dart          # Patient record
        │   ├── prescription_model.dart     # Prescriptions with medicine item rows
        │   ├── appointment_model.dart      # Appointments with confirmation tracking
        │   ├── notification_model.dart     # Communication log records
        │   └── timeline_event_model.dart   # Patient care journey events
        ├── services/
        │   ├── auth_service.dart           # Auth, token refresh, and role detection
        │   ├── admin_service.dart          # Admin doctor management
        │   ├── patient_service.dart        # Patient CRUD & registration triggers
        │   ├── prescription_service.dart   # Storage upload, AI extraction, auto follow-up
        │   ├── appointment_service.dart    # Appointment scheduling & status workflows
        │   ├── notification_service.dart   # Real-time communication history stream
        │   ├── timeline_service.dart       # Smart timeline event aggregator
        │   ├── demo_service.dart           # Live demo reminder engine trigger
        │   └── connectivity_service.dart   # Network monitor
        └── screens/
            ├── auth/login_screen.dart
            ├── admin/
            │   ├── admin_dashboard_screen.dart
            │   ├── doctor_list_screen.dart
            │   └── add_doctor_screen.dart
            └── doctor/
                ├── doctor_shell_screen.dart # Bottom Navigation Shell
                ├── doctor_dashboard_screen.dart # Today's Visits, Follow-ups Due, Pending Confirmations
                ├── patients/
                │   ├── patient_list_screen.dart
                │   ├── add_patient_screen.dart
                │   └── patient_detail_screen.dart # 5 Tabs: Overview, Rx, Visits, Timeline, Comms
                ├── prescriptions/
                │   └── add_prescription_screen.dart # Manual/Upload + AI Review + Follow-up Scheduler
                ├── appointments/
                │   ├── appointment_list_screen.dart # Filterable: Today, Upcoming, Missed / Review
                │   └── add_appointment_screen.dart
                ├── communication/
                │   └── communication_history_screen.dart
                └── settings/
                    ├── demo_settings_screen.dart # Demo mode offset selector & immediate test trigger
                    └── profile_screen.dart
```

---

## 2. Key Features Implemented

1. **Role-Based Isolation (Security & RBAC):**
   - Admin accounts can create doctors and toggle access.
   - Doctor accounts only see their own patients, prescriptions, and visits (`doctorId == request.auth.uid`).
   - Zero sensitive API keys (Gemini, WhatsApp, Gmail) are included in client code.

2. **Prescription Engine & Gemini AI Integration:**
   - Manual medicine entry + Image/PDF upload to Firebase Storage.
   - AI extraction endpoint reads medicines, dosage, and follow-up hints.
   - Prominent clinical disclaimer banner: *"AI extracted information. Please verify before saving."*
   - Deterministic follow-up engine (+3 months default, 15 days, 1 month, 6 months, custom date).
   - Auto-creates the follow-up appointment in Firestore on doctor confirmation.

3. **Smart Patient Timeline (Feature 1):**
   - Aggregates Patient Registration, Prescriptions, Follow-up Schedules, Reminders, and Appointment Statuses into a chronological care journey.

4. **Follow-ups Due Dashboard (Feature 2):**
   - Live categorized metrics: *Due Today*, *Due in 3 Days*, *Due in 7 Days*, and *Overdue*.

5. **Patient Confirmation & No-Response Tracking (Features 3, 4, 5):**
   - Public HTTPS endpoint for 1-click confirmation / reschedule request.
   - Real-time status badges (*Confirmed*, *Pending*, *Reschedule Requested*, *Missed*).
   - One-tap reminder resend.

6. **Communication History (Feature 6):**
   - Every email, SMS, and push attempt is logged in `notifications/{id}` with exact delivery statuses and error descriptions.

7. **Scheduled Reminder Engine & Demo Mode (Features 7 & 18):**
   - Idempotent 24-hour reminder scheduler (`reminder24hSent: true` deduplication).
   - Development-only **Demo Mode** with configurable 1m / 5m / 10m offsets and on-demand trigger.

---

## 3. Verification & Demo Flow

### Backend Compilation:
```bash
cd functions
npx tsc --noEmit
# Result: 0 errors, build succeeds cleanly
```

### Live Demo Steps:
1. **Admin Login & Doctor Setup:**
   - Login as Admin → Go to *Manage Doctors* → *Add Doctor* (e.g. Dr. Rajesh Sharma) → Doctor account created in Firebase Auth with `role: 'doctor'`.
2. **Doctor Patient Onboarding:**
   - Login as Dr. Sharma → Tap *+ Add Patient* → Enter details → Patient saved in Firestore under Dr. Sharma's UID. Welcome Email / SMS triggered.
3. **Prescription & AI Extraction:**
   - Open patient → Tap *+ Add Prescription* → Upload document or enter medicines → Tap *Extract Details with AI* → Review extracted list → Select follow-up interval (+3 months) → Tap *Confirm & Schedule Follow-up*.
4. **Timeline & Follow-up Verification:**
   - View Patient *Timeline* tab: see Registration → Prescription → Follow-up Scheduled.
   - Check *Dashboard*: see upcoming appointment and follow-up category counts.
5. **Demo Reminder Test:**
   - Open *Profile* → *Demo / Test Reminder Mode* → Turn ON with 5 Minutes offset → Schedule visit at `Current Time + 5 min` → Tap *Trigger Reminder Check Now* → Open Patient *Communication* tab to verify real logged notification record.
