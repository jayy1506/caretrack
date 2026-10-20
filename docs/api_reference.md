# CareTrack API & Cloud Functions Reference

This reference details the public HTTP endpoints, authenticated Cloud Functions callables, security protections (App Check, rate limiting, CAPTCHA, HMAC signatures), and approved Meta WhatsApp templates.

---

## 1. Public HTTP Endpoints & Protections

### 1.1 Meta WhatsApp Inbound Webhook
- **URL**: `https://<region>-<project-id>.cloudfunctions.net/whatsappWebhook`
- **Method**: `GET` (Handshake verification) | `POST` (Message Ingestion)
- **Security & Anti-Abuse Protections**:
  - **HMAC-SHA256 Verification**: Payload signature checked against `X-Hub-Signature-256` using `META_WEBHOOK_VERIFY_TOKEN`.
  - **IP Rate Limiting**: Max 60 requests per minute per IP address.
  - **Replay Protection**: Messages with identical `wamid` are deduplicated.
- **GET Request (Verification Handshake)**:
  - Query Parameters: `hub.mode=subscribe`, `hub.challenge=<num>`, `hub.verify_token=<token>`
  - Response: Returns `hub.challenge` on success (status `200`).
- **POST Request (Payload Ingestion)**:
  - Handles inbound user text messages, quick reply button clicks (`CONFIRM_APPOINTMENT`, `RESCHEDULE_APPOINTMENT`), and interactive list selections.
  - Passes inbound text to the Emergency Triage Engine.

---

### 1.2 Public Slot Availability (`getAvailableSlotsPublic`)
- **URL**: `https://<region>-<project-id>.cloudfunctions.net/getAvailableSlotsPublic`
- **Method**: `POST`
- **Security & Anti-Abuse Protections**:
  - **App Check**: Required for web/mobile requests.
  - **Rate Limiting**: Max 30 requests per minute per IP.
  - **Enumeration Protection**: Only returns open time slot strings (e.g. `["09:30 AM", "10:00 AM"]`). Never exposes patient names, doctor calendar entries, or booked client IDs.
- **Request Body**:
  ```json
  {
    "clinicId": "pilot-dental-clinic",
    "date": "2026-10-22"
  }
  ```
- **Response**:
  ```json
  {
    "clinicId": "pilot-dental-clinic",
    "date": "2026-10-22",
    "availableSlots": ["09:00 AM", "09:30 AM", "11:00 AM", "02:30 PM", "04:00 PM"]
  }
  ```

---

### 1.3 Public Slot Booking (`bookAppointmentPublic`)
- **URL**: `https://<region>-<project-id>.cloudfunctions.net/bookAppointmentPublic`
- **Method**: `POST`
- **Security & Anti-Abuse Protections**:
  - **reCAPTCHA Enterprise / Cloudflare Turnstile**: Validates CAPTCHA token before processing.
  - **Rate Limiting**: Max 5 booking requests per 10 minutes per IP/phone number.
  - **Atomic Transaction**: Uses Firestore transaction to guarantee no double-booking for the same chair slot.
  - **HMAC Signed Token**: Generates a tamper-proof HMAC-SHA256 token returned to the patient for self-service cancellation/rescheduling.
- **Request Body**:
  ```json
  {
    "clinicId": "pilot-dental-clinic",
    "patientName": "Ramesh Verma",
    "patientPhone": "+919811122233",
    "patientEmail": "ramesh.verma@example.com",
    "date": "2026-10-22",
    "time": "10:30 AM",
    "reason": "Tooth Sensitivity Checkup",
    "captchaToken": "03AFcWeA...",
    "messagingConsent": true
  }
  ```
- **Response**:
  ```json
  {
    "success": true,
    "appointmentId": "appt-123456",
    "status": "pending",
    "managementToken": "eyJhbGciOiJIUzI1NiIsIn...",
    "message": "Appointment requested! Clinic will confirm shortly."
  }
  ```

---

### 1.4 Public Cancel / Reschedule (`cancelOrReschedulePublic`)
- **URL**: `https://<region>-<project-id>.cloudfunctions.net/cancelOrReschedulePublic`
- **Method**: `POST`
- **Security**: Validates that the provided `managementToken` matches the appointment's signed cryptographic payload.
- **Request Body**:
  ```json
  {
    "appointmentId": "appt-123456",
    "managementToken": "eyJhbGciOiJIUzI1NiIsIn...",
    "action": "cancel", // or "reschedule"
    "newDate": "2026-10-24",
    "newTime": "11:00 AM"
  }
  ```

---

## 2. Authenticated Cloud Functions Callables

All callables require a valid Firebase Auth ID token and are verified against custom claims.

### 2.1 Staff Management & Onboarding
- **`assignStaffRole`**
  - **Permission**: `isOwner: true` (Clinic Owner only)
  - **Input**: `{ targetUid: string, role: 'doctor' | 'receptionist' | 'owner', clinicId?: string }`
  - **Action**: Sets custom claims on target user and updates `users/{uid}`.
  - **Audit**: Logged as `STAFF_ROLE_CHANGED`.

---

### 2.2 Treatment Plans & Scheduling
- **`completeTreatmentPlanStage`**
  - **Permission**: `canEdit: true` (Doctor or Owner)
  - **Input**: `{ planId: string, stageNumber: number, clinicId?: string }`
  - **Action**: Marks the specified stage as `completed`, auto-advances next stage, and generates a scheduled follow-up proposal.
- **`generateFollowUpProposal`**
  - **Permission**: `canEdit: true` (Doctor or Owner)
  - **Input**: `{ patientId: string, planId: string, stageNumber: number }`
  - **Action**: Inspects treatment stage requirements and recommends follow-up date and WhatsApp recall template.

---

### 2.3 AI Features (Suggestions, Human-Confirmed)
- **`parsePrescriptionWithGemini`**
  - **Permission**: `isDoctor: true` or `isOwner: true`
  - **Input**: `{ imageStoragePath: string, clinicId?: string }`
  - **Action**: Parses Rx scan into structured medicines, dosages, and recommended follow-up recall interval using Gemini 1.5 Flash.
  - **Clinical Safety**: All outputs are flagged as suggestions and require human doctor confirmation before persisting.

---

### 2.4 DPDP Compliance & Data Rights
- **`exportPatientData`**
  - **Permission**: `isOwner: true` (Clinic Owner only)
  - **Input**: `{ patientId: string, clinicId?: string }`
  - **Output**: Complete structured JSON containing patient profile, prescriptions, appointments, treatment plans, medication adherence logs, and chat messages.
  - **Audit**: Logged as `PATIENT_DATA_EXPORTED`.
- **`erasePatientData`**
  - **Permission**: `isOwner: true` (Clinic Owner only)
  - **Input**: `{ patientId: string, reason: string, clinicId?: string }`
  - **Action**: Anonymizes patient document, deletes prescription scan files from Cloud Storage, and cleans clinical subcollections.
  - **Audit**: Logged as `PATIENT_DATA_ERASED` with recorded clinical reason.
- **`updatePatientConsent`**
  - **Permission**: Authenticated staff
  - **Input**: `{ patientId: string, messagingConsent: boolean, messagingConsentMethod: string, aiProcessingConsent: boolean, aiProcessingConsentMethod: string, consentNotes?: string }`
  - **Audit**: Logged as `PATIENT_CONSENT_UPDATED`.
- **`submitFeedback`**
  - **Permission**: Authenticated staff
  - **Input**: `{ clinicId: string, category: string, satisfactionScore: number, feedbackText: string }`
  - **Action**: Writes to `feedback/{feedbackId}`.

---

## 3. Approved Meta WhatsApp Message Templates

The following templates are pre-approved and configured in Meta WhatsApp Cloud API:

| Template Name | Category | Language | Variables | Interactive Buttons |
| :--- | :--- | :--- | :--- | :--- |
| `appointment_confirmation_v1` | UTILITY | `en`, `hi` | `{{1}}`: Patient Name<br>`{{2}}`: Date<br>`{{3}}`: Time<br>`{{4}}`: Clinic Name | None |
| `appointment_reminder_24h_v1` | UTILITY | `en`, `hi` | `{{1}}`: Patient Name<br>`{{2}}`: Time Tomorrow<br>`{{3}}`: Clinic Name | Quick Reply: **Confirm**, **Reschedule** |
| `appointment_rescheduled_v1` | UTILITY | `en`, `hi` | `{{1}}`: Patient Name<br>`{{2}}`: New Date<br>`{{3}}`: New Time | None |
| `treatment_stage_recall_v1` | UTILITY | `en`, `hi` | `{{1}}`: Patient Name<br>`{{2}}`: Stage Procedure<br>`{{3}}`: Recommended Date | Quick Reply: **Book Slot** |
| `medication_reminder_v1` | UTILITY | `en`, `hi` | `{{1}}`: Patient Name<br>`{{2}}`: Medicine Name & Dose<br>`{{3}}`: Instructions | Quick Reply: **Taken** |
| `routine_checkup_recall_v1` | UTILITY / MARKETING | `en`, `hi` | `{{1}}`: Patient Name<br>`{{2}}`: Month Interval (3/6m)<br>`{{3}}`: Clinic Name | URL Button: **Book Online** |
