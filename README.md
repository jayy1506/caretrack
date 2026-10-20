# 🩺 CareTrack — Doctor Follow-up & Patient Reminder System

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-v2_Cloud_Functions-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.x-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Node.js](https://img.shields.io/badge/Node.js-20_LTS-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![Google Gemini](https://img.shields.io/badge/AI-Gemini_1.5_Flash-8E75C2?logo=google&logoColor=white)](https://ai.google.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**CareTrack** is an enterprise-grade clinic management, prescription digitization, and automated patient follow-up ecosystem designed for dental clinics and healthcare providers. It eliminates manual follow-up tracking, reduces appointment no-shows, and streamlines patient communication using AI-powered prescription parsing, deterministic follow-up scheduling, and multi-channel automated reminders (Email, SMS, Push).

---

## 📑 Table of Contents

- [System Architecture](#-system-architecture)
- [Key Features](#-key-features)
- [Tech Stack](#-tech-stack)
- [Project Directory Structure](#-project-directory-structure)
- [Database Schema & Security Rules](#-database-schema--security-rules)
- [Cloud Functions Reference](#-cloud-functions-reference)
- [Prerequisites & Environment Variables](#-prerequisites--environment-variables)
- [Local Development & Setup Guide](#-local-development--setup-guide)
  - [1. Backend & Firebase Emulators](#1-backend--firebase-emulators)
  - [2. Flutter Mobile Application](#2-flutter-mobile-application)
- [Live Demo & Verification Workflow](#-live-demo--verification-workflow)
- [Deployment](#-deployment)
- [Contributing & License](#-contributing--license)

---

## 🏛 System Architecture

CareTrack is composed of two primary sub-systems working in synchrony:

1. **CareTrack Mobile App (`caretrack_app`)**: Modern Android application built in Flutter with Material 3 design, role-based views (Clinic Admin vs Doctor), offline resilience, intelligent timeline feeds, and real-time Firestore synchronization.
2. **CareTrack Cloud Functions (`functions`)**: Modular 2nd Gen Firebase Cloud Functions written in TypeScript, orchestrating Gemini vision extraction, transactional communications via Nodemailer (Gmail SMTP) and WhatsApp Cloud API / Telegram, and idempotent cron-based reminder engines.

```
                          ┌─────────────────────────────────────┐
                          │     CareTrack Mobile Application    │
                          │   (Flutter / Android / Material 3)  │
                          └──────────────────┬──────────────────┘
                                             │
                       ┌─────────────────────┴─────────────────────┐
                       │                                           │
                       ▼                                           ▼
            ┌──────────────────────┐                    ┌──────────────────────┐
            │   Firebase Auth &    │                    │ Cloud Functions v2   │
            │   Cloud Firestore    │                    │ (TypeScript/Node 20) │
            │  (Rules & Isolation) │                    └──────────┬───────────┘
            └──────────────────────┘                               │
                                       ┌───────────────────────────┼───────────────────────────┐
                                       ▼                           ▼                           ▼
                            ┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
                            │  Google Gemini AI   │     │  Gmail SMTP (Email) │     │   Firebase Cloud    │
                            │  (Vision & Parsing) │     │  & WhatsApp API     │     │  Messaging (Push)   │
                            └─────────────────────┘     └─────────────────────┘     └─────────────────────┘
```

---

## ✨ Key Features

### 1. 🛡️ Role-Based Access Control (RBAC) & Data Isolation
- **Admin Role**: Create doctor accounts, configure clinic settings, toggle doctor active/inactive status, and supervise clinic-wide operations.
- **Doctor Role**: Strictly isolated workspace. Doctors only access their own patients, prescriptions, appointments, and communication logs.
- **Zero Client-Side Secrets**: All third-party API credentials (Gemini, WhatsApp, Gmail) are quarantined inside Cloud Functions.
 
### 2. 🤖 AI Prescription Parsing & Auto Follow-up
- Upload prescription camera photos or PDF documents directly to Firebase Storage.
- Gemini Flash parses handwritten or printed prescriptions into structured medicines, dosages, frequencies, and durations.
- Clinical safety guard: *"AI extracted information. Please verify before saving."*
- Deterministic calendar follow-up calculator (+3 months default, 15 days, 1 month, 6 months, or custom date) with auto-creation of follow-up appointments.
 
### 3. 📅 Doctor Dashboard & Follow-ups Due Pipeline
- Real-time categorized metrics:
  - **Due Today**: Immediate follow-ups requiring attention.
  - **Due in 3 Days**: Upcoming patient visits.
  - **Due in 7 Days**: Planning horizon.
  - **Overdue**: Patients who missed their follow-up window.
- Quick filter tabs for today's visits, pending confirmations, and missed appointments.
 
### 4. 📜 Smart Patient Care Timeline
- Chronological, unified patient care journey aggregating:
  - Patient onboarding & welcome notification
  - Prescriptions & medication changes
  - Scheduled follow-up appointments
  - Automated notification delivery audits (Email / WhatsApp)
  - Confirmation / reschedule actions
 
### 5. 📨 Multi-Channel Reminders & 1-Click Patient Confirmation
- Dynamic notification dispatch via **Email (Gmail SMTP)**, **Messaging (WhatsApp Cloud API / Telegram)**, and **Push (FCM)**.
- Public web confirmation link (`/confirmAppointmentWeb`) allowing patients to confirm or request a reschedule with a single tap from WhatsApp or Email without needing to install the app.
- Status badges: `Confirmed`, `Pending`, `Reschedule Requested`, `Missed`.
 
### 6. 🧪 Scheduled Reminder Cron & Interactive Demo Mode
- **Production Engine**: 24-hour idempotent cron job that runs daily, detects appointments within the next 24 hours, and sends reminders without duplicate triggers (`reminder24hSent` flag).
- **Demo Mode**: Built-in developer testing mode allowing customizable short test offsets (1 min, 5 min, 10 min) and an immediate trigger button to demonstrate reminder alerts during evaluations.
 
---
 
## 🛠 Tech Stack
 
| Domain | Technologies |
|---|---|
| **Mobile App** | [Flutter 3.x](https://flutter.dev), [Dart 3.x](https://dart.dev), [Provider](https://pub.dev/packages/provider), Material Design 3, Google Fonts |
| **Backend** | [Firebase Cloud Functions v2](https://firebase.google.com/docs/functions), [Node.js 20](https://nodejs.org), [TypeScript 5](https://www.typescriptlang.org) |
| **Database & Auth** | [Cloud Firestore](https://firebase.google.com/docs/firestore), [Firebase Authentication](https://firebase.google.com/docs/auth), [Firebase Storage](https://firebase.google.com/docs/storage) |
| **Artificial Intelligence** | [Google Generative AI](https://www.npmjs.com/package/@google/generative-ai) (Gemini Flash) |
| **Communication Providers** | [Nodemailer](https://nodemailer.com) (Gmail SMTP), [WhatsApp Cloud API](https://developers.facebook.com/docs/whatsapp/cloud-api), [Telegram Bot API](https://core.telegram.org/bots/api), [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging) |
| **Validation & Emulation** | [Zod](https://zod.dev), Firebase Local Emulator Suite |
 
---
 
## 📂 Project Directory Structure
 
```text
dental/
├── firebase.json                           # Firebase CLI configuration & local emulator ports
├── firestore.rules                         # Multi-tenant security rules with RBAC isolation
├── storage.rules                           # Cloud Storage access rules for prescription files
├── firestore.indexes.json                  # Firestore composite queries index specifications
├── walkthrough.md                          # Architecture walkthrough and testing documentation
├── README.md                               # Comprehensive project documentation
│
├── functions/                              # 2nd Gen Firebase Cloud Functions (TypeScript)
│   ├── package.json                        # Backend dependencies & compilation scripts
│   ├── tsconfig.json                       # TypeScript compiler options
│   ├── .env.example                        # Template for backend secrets and API keys
│   └── src/
│       ├── index.ts                        # Main Cloud Functions export hub
│       ├── config/                         # Firebase Admin SDK & environment initialization
│       ├── types/                          # Shared domain schemas & TypeScript definitions
│       ├── services/
│       │   ├── followUpService.ts          # Deterministic calendar math & scheduling
│       │   ├── geminiService.ts            # Gemini structured prescription extractor
│       │   ├── emailService.ts             # Gmail SMTP client & clinical HTML email templates
│       │   ├── messagingService.ts         # WhatsApp Cloud API & Telegram messaging provider
│       │   ├── pushService.ts              # Firebase Cloud Messaging dispatcher
│       │   └── notificationService.ts      # Multi-channel orchestrator & Firestore audit logger
│       ├── auth/                           # Admin callable: createDoctor, toggleDoctorStatus
│       ├── patients/                       # Onboarding callable: sendPatientRegistrationNotification
│       ├── prescriptions/                  # AI callable: extractPrescriptionData
│       ├── appointments/                   # Callables & Webhooks: confirmAppointmentWeb, sendAppointmentConfirmation
│       ├── notifications/                  # Direct messaging callable & SMS webhooks
│       └── scheduled/                      # Cron: scheduledReminderEngine & triggerDemoReminderCheck
│
└── caretrack_app/                          # Android Client Application (Flutter / Dart)
    ├── pubspec.yaml                        # Flutter package dependencies & asset manifests
    ├── android/                            # Android native configurations & manifests
    └── lib/
        ├── main.dart                       # App initialization, MultiProvider, Auth Gate
        ├── firebase_options.dart           # Firebase client configuration credentials
        ├── core/
        │   ├── theme/app_theme.dart        # Clinical Navy/Slate color palette & Material 3 styles
        │   ├── utils/date_formatter.dart   # Clinical date formatting & interval helpers
        │   └── widgets/                    # Reusable UI widgets (Buttons, Badges, Banners, Form inputs)
        ├── models/                         # Domain models (User, Patient, Rx, Appointment, Notification)
        ├── services/                       # Data layer services (Auth, Admin, Patient, Rx, Appointment)
        └── screens/
            ├── auth/login_screen.dart      # Email/Password authentication & role detection
            ├── admin/                      # Admin views (Admin Dashboard, Doctor List, Add Doctor)
            └── doctor/                     # Doctor views:
                ├── doctor_shell_screen.dart       # Bottom navigation container
                ├── doctor_dashboard_screen.dart   # Action metrics & categorized follow-up cards
                ├── patients/                      # Patient list, Add patient, 5-tab Patient detail
                ├── prescriptions/                # Manual entry, AI upload review, Follow-up picker
                ├── appointments/                 # Today, Upcoming, and Missed appointment lists
                ├── communication/                # Live communication delivery log & status audit
                └── settings/                     # Doctor profile & Demo Mode simulation screen
```

---

## 🗄 Database Schema & Security Rules

### Firestore Collections

| Collection | Path | Description | Access Control |
|---|---|---|---|
| **Users** | `/users/{userId}` | Admin and Doctor profiles with role metadata (`role: 'admin' \| 'doctor'`) | Admin: Read/Write all; User: Read self |
| **Patients** | `/patients/{patientId}` | Demographics, medical history, primary contact details, assigned `doctorId` | Doctor: CRUD own patients; Admin: Read |
| **Prescriptions** | `/prescriptions/{rxId}` | Prescription records, medicine arrays, dosage, file URL, follow-up metadata | Doctor: CRUD own patients' Rx; Admin: Read |
| **Appointments** | `/appointments/{appId}` | Follow-ups, visit dates, status (`pending`, `confirmed`, `missed`), reminders | Doctor: CRUD own appointments; Admin: Read |
| **Notifications** | `/notifications/{notifId}`| Multi-channel audit trail (channel, status, recipient, timestamp, error) | Doctor: Read own notifications; Admin: Read |

### Security Model (`firestore.rules`)
- **Strict Data Isolation**: Queries on `/patients`, `/prescriptions`, and `/appointments` require `doctorId == request.auth.uid`. Doctors cannot access records belonging to other practitioners.
- **Admin Guardrails**: Only authenticated administrators can toggle doctor statuses or provision new doctor credentials.

---

## ⚡ Cloud Functions Reference

CareTrack exports 2nd-generation Cloud Functions optimized for concurrency and minimal cold starts:

| Function Name | Type | Description |
|---|---|---|
| `createDoctor` | `onCall` | Allows Admins to provision a new Doctor with custom role claims |
| `toggleDoctorStatus` | `onCall` | Allows Admins to enable or suspend a Doctor's account |
| `sendPatientRegistrationNotification` | `onCall` | Dispatches welcome email/WhatsApp to newly registered patients |
| `extractPrescriptionData` | `onCall` | Sends prescription image/PDF to Gemini Flash and returns structured JSON |
| `confirmAppointmentWeb` | `onRequest` | Public HTTPS endpoint for patients to confirm or reschedule via web browser |
| `sendAppointmentConfirmation` | `onCall` | Manually triggers confirmation requests to a patient |
| `sendDirectMessage` | `onCall` | Allows doctors to send custom communications to a patient |
| `apiSendMessage` | `onRequest` | Protected HTTP endpoint requiring Bearer ID token with doctor role for clinic messaging |
| `scheduledReminderEngine` | Scheduled Cron | Runs every 24 hours at 08:00 AM; checks and dispatches due reminders |
| `triggerDemoReminderCheck` | `onCall` | Immediate evaluation trigger for demo testing mode |

---

## ⚙️ Prerequisites & Environment Variables

### Prerequisites
- **Flutter SDK**: `^3.0.0` ([Install Flutter](https://docs.flutter.dev/get-started/install))
- **Node.js**: `v20.x LTS` ([Install Node.js](https://nodejs.org/))
- **Firebase CLI**: `npm install -g firebase-tools`
- **Android Studio** or physical Android device with USB debugging enabled

### Backend Environment Configuration
Copy the sample environment file in `functions/` and configure your API keys:

```bash
cd functions
cp .env.example .env
```

Edit `functions/.env`:

```ini
# Gemini API Key (from Google AI Studio)
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=gemini-2.5-flash

# Email Configuration (Nodemailer via Gmail SMTP)
GMAIL_USER=your_clinic_email@gmail.com
GMAIL_APP_PASSWORD=your_gmail_16_digit_app_password

# Messaging Provider: whatsapp | telegram | none
MESSAGING_PROVIDER=whatsapp

# WhatsApp Cloud API (Meta Graph API)
WHATSAPP_PHONE_NUMBER_ID=your_whatsapp_phone_number_id
WHATSAPP_ACCESS_TOKEN=your_meta_system_user_access_token

# Telegram Bot (Optional)
TELEGRAM_BOT_TOKEN=your_telegram_bot_token

# Cloud Functions base URL (for patient confirmation links)
BASE_APP_URL=https://us-central1-your-project-id.cloudfunctions.net
```

---

## 🚀 Local Development & Setup Guide

### 1. Backend & Firebase Emulators

1. **Install dependencies**:
   ```bash
   cd functions
   npm install
   ```

2. **Compile TypeScript**:
   ```bash
   npm run build
   ```

3. **Start Firebase Local Emulators** (Functions, Firestore, Storage, Auth, UI):
   ```bash
   # From the root directory:
   firebase emulators:start
   ```
   - **Emulator UI**: Open [http://localhost:4000](http://localhost:4000)
   - **Firestore Emulator**: Port `8080`
   - **Functions Emulator**: Port `5001`
   - **Auth Emulator**: Port `9099`

---

### 2. Multi-Environment Project Management (Dev, Staging, Prod)

CareTrack separates development, staging, and production environments via project aliases in `.firebaserc`:

```bash
# View active project alias
firebase use

# Switch between environments
firebase use development   # caretrack-dev
firebase use staging       # caretrack-staging
firebase use production    # caretrack-prod

# Deploy to active target environment
firebase deploy --only firestore:rules,firestore:indexes,functions
```

Automated daily backups run at 02:00 AM IST via `scheduledFirestoreBackup`. For disaster recovery, see [docs/BACKUP_RESTORE_RUNBOOK.md](docs/BACKUP_RESTORE_RUNBOOK.md).

---

### 3. Flutter Mobile Application

1. **Navigate to the app directory**:
   ```bash
   cd caretrack_app
   ```

2. **Install Flutter packages**:
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**:
   Ensure `caretrack_app/lib/firebase_options.dart` points to your configured Firebase project or local emulator.

4. **Run on Android Emulator or Device**:
   ```bash
   flutter run
   ```

---

## 🧪 Live Demo & Verification Workflow

Follow this end-to-end verification sequence to test the entire application:

### Step 1: Admin Doctor Provisioning
1. Launch the app and log in with an **Admin** account.
2. Navigate to **Manage Doctors** > **Add Doctor**.
3. Create a doctor account (e.g., `Dr. Rajesh Sharma`, `dr.sharma@example.com`).
4. The doctor record is stored in Firestore and custom claims are assigned.

### Step 2: Patient Registration & Notification
1. Log out and log in as `dr.sharma@example.com`.
2. Tap **+ Add Patient**, enter patient details (Name, Phone, Email, Medical Notes).
3. Tap **Save Patient**. The patient receives an automated welcome notification via Email/SMS.

### Step 3: AI Prescription Parsing & Follow-up Scheduling
1. Open the created patient profile > Tap **+ Add Prescription**.
2. Upload a prescription image/PDF or enter medicine details.
3. Tap **Extract Details with AI** (powered by Gemini 1.5 Flash).
4. Review the parsed medicines and dosages.
5. Select a follow-up interval (e.g., `+3 Months`).
6. Tap **Confirm & Schedule Follow-up**. An appointment is automatically registered.

### Step 4: Care Timeline & Follow-ups Due Verification
1. Inspect the patient's **Timeline** tab to observe the chronological journey:
   - `Registration` → `Prescription Added` → `Follow-up Scheduled`.
2. Return to the **Doctor Dashboard** to observe the updated counters under **Follow-ups Due**:
   - Categorized by `Due Today`, `Due in 3 Days`, `Due in 7 Days`, and `Overdue`.

### Step 5: Demo Mode & Reminder Triggering
1. Navigate to **Settings** > **Demo / Test Reminder Mode**.
2. Toggle Demo Mode **ON** and set the offset (e.g., `5 Minutes`).
3. Schedule an appointment at `Current Time + 5 minutes`.
4. Tap **Trigger Reminder Check Now**.
5. Navigate to the patient's **Communication** tab to view the live logged reminder delivery event.

---

## 🚢 Deployment

### Deploying Cloud Functions and Security Rules
Ensure you are logged into the Firebase CLI and your project is selected:

```bash
firebase login
firebase use your-project-id
```

Deploy all services:
```bash
firebase deploy
```

Or deploy components selectively:
```bash
# Deploy Firestore rules and indexes only
firebase deploy --only firestore

# Deploy Storage rules only
firebase deploy --only storage

# Deploy Cloud Functions only
firebase deploy --only functions
```

### Building the Android APK
```bash
cd caretrack_app
flutter build apk --release
```
The production APK will be generated at `caretrack_app/build/app/outputs/flutter-apk/app-release.apk`.

---

## 📄 Contributing & License

Contributions are welcome! Please follow clean code standards and ensure `tsc --noEmit` and `flutter analyze` pass cleanly before submitting pull requests.

This project is licensed under the **MIT License**.
