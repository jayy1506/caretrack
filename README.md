# 🦷 CareTrack — Clinical Retention Platform for Dental Clinics

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-v2_Cloud_Functions-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.x-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Node.js](https://img.shields.io/badge/Node.js-20_LTS-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![Google Gemini](https://img.shields.io/badge/AI-Gemini_1.5_Flash-8E75C2?logo=google&logoColor=white)](https://ai.google.dev)
[![Meta WhatsApp API](https://img.shields.io/badge/Messaging-Meta_WhatsApp_Cloud_API-25D366?logo=whatsapp&logoColor=white)](https://developers.facebook.com/docs/whatsapp/cloud-api)
[![DPDP Act 2023](https://img.shields.io/badge/Compliance-DPDP_Act_2023-10B981)](https://www.meity.gov.in)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**CareTrack** is an enterprise-grade clinical retention and patient engagement platform purpose-built for dental clinics. It evolves traditional clinic software into an active patient relationship engine: automating multi-stage treatment plans, tracking medication adherence, conducting two-way WhatsApp patient communication with automated emergency triage, and suggesting recall intervals via Gemini 1.5 Flash—all while maintaining strict multi-tenant isolation, human clinical confirmation, and DPDP Act 2023 compliance.

> [!IMPORTANT]
> **Strict Clinical Scope Boundary**: CareTrack is exclusively focused on clinical workflow and patient retention. There are **zero payment, billing, invoice, UPI, or subscription features** in the platform.

---

## 📑 Table of Contents

- [Core Platform Capabilities](#-core-platform-capabilities)
- [System Architecture](#-system-architecture)
- [Multi-Clinic Tenant Isolation & Staff Roles](#-multi-clinic-tenant-isolation--staff-roles)
- [DPDP Act 2023 Compliance & Data Protection](#-dpdp-act-2023-compliance--data-protection)
- [AI Clinical Advisory (Human-in-the-Loop)](#-ai-clinical-advisory-human-in-the-loop)
- [Documentation Index](#-documentation-index)
- [Repository Structure](#-repository-structure)
- [Local Development & Verification](#-local-development--verification)
- [Pilot Clinic Seeding & Operational Runbook](#-pilot-clinic-seeding--operational-runbook)

---

## 🌟 Core Platform Capabilities

### 1. Multi-Stage Dental Treatment Plans
- Structured treatment pipelines for multi-visit procedures (Root Canal Therapy, Orthodontic Aligners, Dental Implants, Periodontal Scaling).
- Auto-advances next stages upon clinical completion and queues automated follow-up proposals in the clinic reception feed.

### 2. Two-Way Meta WhatsApp Engagement & Emergency Triage
- Ingests inbound patient WhatsApp messages via secure Cloud Function webhook (`X-Hub-Signature-256` HMAC-SHA256 verified).
- **Emergency Triage Engine**: Automatically scans inbound patient messages for critical symptoms ("swelling", "bleeding", "severe pain", "fever", "pus") and tags conversations as `urgent` with high-priority clinic inbox alerts.
- Interactive WhatsApp Quick Reply buttons for 24-hour appointment confirmations and reschedules.

### 3. Medication Reminders & Adherence Tracking
- Automated dose reminders delivered to patient phones for antibiotic and pain management courses.
- Patient "Taken" confirmation tracking with live adherence percentages displayed in doctor dashboards.

### 4. Smart Public Slot Booking & Management
- Anti-abuse protected online booking widget (IP rate-limiting, App Check, CAPTCHA).
- Returns cryptographically signed HMAC-SHA256 management tokens for patient self-service slot cancellation and rescheduling without requiring patient account creation.

### 5. Responsive Material 3 Design
- Unified Design System with curated tokens (`primaryNavy`, `primaryTeal`, `mintAccent`, `backgroundGrey`).
- Adaptive **Receptionist Split-Screen Shell**: Dual-pane master-detail view on desktop/web screens (>900px), transforming seamlessly into an intuitive bottom navigation experience on mobile screens.
- Full Light and Dark mode support with high-contrast clinical status badges.

---

## 🏛 System Architecture

CareTrack pairs a high-performance Flutter client with Firebase Cloud Functions v2 and Google Cloud services:

```
+-----------------------------------------------------------------------------------+
|                           CARETRACK CLIENT APPLICATIONS                           |
|                                                                                   |
|  +--------------------------------+          +---------------------------------+  |
|  |     Flutter Web / Desktop      |          |       Flutter Mobile (Android)  |  |
|  |   - Receptionist Split Shell   |          |   - Doctor & Staff Mobile App   |  |
|  |   - Responsive Dashboard       |          |   - Instant Notification Feed   |  |
|  +--------------------------------+          +---------------------------------+  |
+------------------------------------------+----------------------------------------+
                                           | HTTPS / WSS (App Check Protected)
                                           v
+-----------------------------------------------------------------------------------+
|                        CLOUD LOGIC & RUNTIME BOUNDARY                             |
|                                                                                   |
|  Firebase Cloud Functions v2 (TypeScript / Node 20)                              |
|  +------------------------+  +------------------------+  +---------------------+  |
|  |   Callable Functions   |  |   Webhook Endpoints    |  |  Scheduled Tasks    |  |
|  |  - Auth & Role Claims  |  |  - Meta WhatsApp       |  |  - 24h Reminders    |  |
|  |  - Treatment Plans     |  |    (Rate-limited)      |  |  - Recall Campaigns |  |
|  |  - AI Recalls & Parsing|  |  - Public Slot Booking |  |  - Med Reminders    |  |
|  |  - DPDP Consent & Export| |    (CAPTCHA-protected) |  |  - Daily Backups    |  |
|  +------------------------+  +------------------------+  +---------------------+  |
+------------------------------------------+----------------------------------------+
                                           | IAM & Admin SDK
                                           v
+-----------------------------------------------------------------------------------+
|                              DATA & AI SERVICES                                   |
|                                                                                   |
|  +---------------------------+  +--------------------+  +----------------------+  |
|  |     Cloud Firestore       |  |   Cloud Storage    |  |    Google Gemini     |  |
|  |  - Multi-tenant isolation |  |  - Prescription Rx |  |  - Gemini 1.5 Flash  |  |
|  |  - Subcollection isolation|  |    Scans (secure)  |  |  - Structured JSON   |  |
|  |  - Zero-PII Audit Trail   |  |  - Automated GCS   |  |  - Doctor-confirmed  |  |
|  |  - Real-time listeners    |  |    Daily Backups   |  |    clinical advisory |  |
|  +---------------------------+  +--------------------+  +----------------------+  |
+-----------------------------------------------------------------------------------+
```

For detailed sequence diagrams, see [docs/architecture.md](file:///c:/Users/jthak/OneDrive/Attachments/Desktop/dental/docs/architecture.md).

---

## 🔒 Multi-Clinic Tenant Isolation & Staff Roles

Each clinic operate in full isolation identified by `clinicId`. Multi-tenant boundaries are strictly enforced across two defense-in-depth perimeters:

1. **Firestore Security Rules**: Validates that `request.auth.token.clinicId == resource.data.clinicId`.
2. **Staff Role Hierarchy**:
   - **Clinic Owner (`owner`)**: Full clinic configuration, staff onboarding, DPDP data export & permanent erasure, audit log access.
   - **Doctor (`doctor`)**: Clinical treatment planning, prescription management, patient consultation history.
   - **Receptionist (`receptionist`)**: Appointment slot scheduling, check-in management, two-way WhatsApp clinic inbox. Blocked from clinical prescriptions.

---

## 🛡 DPDP Act 2023 Compliance & Data Protection

CareTrack adheres strictly to the Digital Personal Data Protection Act (DPDP Act 2023, India):

- **Explicit Granular Consent**: Stored in `PatientConsentRecord` (`messagingConsent` and `aiProcessingConsent`), along with acquisition method (`in_person`, `whatsapp_opt_in`, `web_booking`, `paper_form`) and audit timestamps.
- **Right to Access (Data Portability)**: Clinic owners can export patient health records as structured JSON (`exportPatientData`).
- **Right to Erasure**: Clinic owners can invoke `erasePatientData` with a mandatory clinical reason. Anonymizes patient records, purges files from Cloud Storage, and logs a zero-PII audit record.
- **Zero Plaintext PII in Logs**: All Cloud Functions scrub names, phone numbers, emails, addresses, and clinical notes before emitting log statements.

---

## 🤖 AI Clinical Advisory (Human-in-the-Loop)

- **Gemini 1.5 Flash Vision**: Digitizes handwritten and printed prescription slips into structured medication lists and follow-up intervals.
- **Strictly Advisory**: All AI suggestions are presented in the `AiPrescriptionReviewScreen` where doctors must review, modify, and explicitly confirm dosages before any clinical record is saved.

---

## 📚 Documentation Index

- [docs/architecture.md](file:///c:/Users/jthak/OneDrive/Attachments/Desktop/dental/docs/architecture.md) — Architectural overview & Mermaid sequence diagrams.
- [docs/data_model.md](file:///c:/Users/jthak/OneDrive/Attachments/Desktop/dental/docs/data_model.md) — Complete Firestore schema, subcollections, indexes, and role matrix.
- [docs/api_reference.md](file:///c:/Users/jthak/OneDrive/Attachments/Desktop/dental/docs/api_reference.md) — Public endpoints, rate limiting, callables, and Meta WhatsApp templates.
- [docs/pilot_checklist.md](file:///c:/Users/jthak/OneDrive/Attachments/Desktop/dental/docs/pilot_checklist.md) — Operational pre-launch runbook.
- [docs/BACKUP_RESTORE_RUNBOOK.md](file:///c:/Users/jthak/OneDrive/Attachments/Desktop/dental/docs/BACKUP_RESTORE_RUNBOOK.md) — Daily Firestore backup and emergency disaster recovery.

---

## 💻 Local Development & Verification

### Prerequisites
- Node.js 20 LTS & npm
- Flutter SDK 3.x (Dart 3.x)
- Firebase CLI (`npm install -g firebase-tools`)

### 1. Backend Validation
```bash
cd functions
npm install
npx tsc --noEmit     # TypeScript type checking (0 errors)
npm test             # Vitest test suite (74 tests passing)
```

### 2. Flutter App Validation
```bash
cd caretrack_app
flutter pub get
flutter analyze      # Dart static analysis (0 issues)
flutter test         # Widget and design system tests
```

---

## 🚀 Pilot Clinic Seeding & Operational Runbook

To pre-seed a realistic demonstration clinic (`pilot-dental-clinic`) with 3 staff members, 5 consented patients, multi-stage treatment plans, medication schedules, and WhatsApp inbox threads:

```bash
# From workspace root
npx ts-node scripts/seed_pilot_clinic.ts
```

To aggregate pilot metrics and generate the operational evaluation report:

```bash
npx ts-node scripts/export_pilot_report.ts
# Generated report saved to docs/pilot_summary_report.md
```
