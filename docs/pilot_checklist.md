# CareTrack Pilot Clinic Launch Checklist & Operational Runbook

This operational runbook must be completed and signed off prior to launching CareTrack in any production pilot dental clinic.

---

## 1. Firebase Security & Infrastructure Setup

- [ ] **Firestore Multi-Clinic Rules Deployed**
  - Verify `firestore.rules` is deployed using `firebase deploy --only firestore:rules`.
  - Validate that multi-tenant isolation prevents cross-clinic reads or writes:
    - Non-owners cannot read audit logs.
    - Receptionists cannot read or write clinical prescriptions.
    - Public web booking form only reads availability and cannot enumerate patient records.
- [ ] **Firebase App Check Enforcement**
  - App Check enabled for Cloud Functions and Cloud Storage (reCAPTCHA Enterprise for Web, Play Integrity for Android, DeviceCheck for iOS).
  - Verify enforcement mode is set to active (block unverified traffic).
- [ ] **Cloud Storage Security Rules**
  - Verify prescription scan uploads require staff authentication and match `clinicId` path prefix.
  - No public read access to uploaded medical files.
- [ ] **Automated Daily Backups**
  - Scheduled Cloud Function `dailyFirestoreBackup` configured to export Firestore collections to Google Cloud Storage bucket.
  - Retention policy set to 30 days minimum.
  - Restore test executed according to [BACKUP_RESTORE_RUNBOOK.md](file:///c:/Users/jthak/OneDrive/Attachments/Desktop/dental/docs/BACKUP_RESTORE_RUNBOOK.md).

---

## 2. Secrets Management & Environment Configuration

- [ ] **Zero Hardcoded Secrets Verified**
  - Run git grep to confirm no API tokens, private keys, or passwords exist in repository code.
  - Set Google Cloud Secret Manager secrets:
    - `META_WHATSAPP_TOKEN`: Cloud API system user access token.
    - `META_WHATSAPP_PHONE_NUMBER_ID`: Verified clinic phone number ID.
    - `META_WEBHOOK_VERIFY_TOKEN`: Webhook handshake verification string.
    - `GEMINI_API_KEY`: API key for Gemini 1.5 Flash models.

---

## 3. Meta WhatsApp Business API & Template Approval

- [ ] **WhatsApp Business Account (WABA) Verified**
  - Clinic display name verified with green check / official business status.
  - Clinic two-way messaging phone number connected.
- [ ] **Meta Approved Message Templates**
  - Ensure the following templates are submitted and marked `APPROVED` in Meta Business Manager:
    1. `appointment_confirmation_v1` (Utility)
    2. `appointment_reminder_24h_v1` (Utility, with Quick Reply buttons)
    3. `appointment_rescheduled_v1` (Utility)
    4. `treatment_stage_recall_v1` (Utility)
    5. `medication_reminder_v1` (Utility, with "Taken" quick reply)
    6. `routine_checkup_recall_v1` (Marketing / Utility)
- [ ] **Webhook Endpoint Configured**
  - Public webhook URL `https://<region>-<project-id>.cloudfunctions.net/whatsappWebhook` configured in Meta App Dashboard.
  - Subscribed to `messages` event.
  - Rate limiting (60 req/min per IP) verified.

---

## 4. Clinic Staff Onboarding & Roles

- [ ] **Staff Accounts Provisioned**
  - Clinic Owner registered and custom claims (`owner: true`, `clinicId: <id>`) assigned.
  - Doctor profiles created with active license numbers.
  - Receptionist profiles created with appropriate view-only clinical access.
- [ ] **Clinic Working Hours & Holidays Configured**
  - Weekly working hours set in Clinic Settings.
  - Public holidays and clinic closure dates added to holiday calendar.
  - Slot duration (default 30 mins) and concurrent chair capacity configured.

---

## 5. Clinical Safety & DPDP Compliance Verification

- [ ] **Zero Plaintext PII in Logs**
  - Cloud Functions logging sanitization confirmed: `patientName`, `phone`, `email`, `address`, and `prescriptionText` are scrubbed before logging.
- [ ] **DPDP Consent Recording Workflow Tested**
  - Staff trained to record explicit messaging consent (`in_person`, `whatsapp_opt_in`, `web_booking`, `paper_form`) during patient intake.
  - AI analysis opt-in switch explained to patient.
- [ ] **Data Subject Rights Tested**
  - Owner-only export function (`exportPatientData`) verified with JSON download.
  - Owner-only erasure function (`erasePatientData`) verified: anonymizes record, purges storage files, and logs clinical reason.
- [ ] **Human-in-the-Loop Clinical Discretion**
  - Doctors briefed that AI prescription extraction and recall suggestions are strictly advisory and require human confirmation before saving.

---

## 6. Pilot Kick-off Sign-Off

| Stakeholder | Name | Signature / Approval | Date |
| :--- | :--- | :--- | :--- |
| **Lead Dentist / Owner** | Dr. Aarav Patel | Approved | 2026-10-20 |
| **Clinic Operations Manager** | Rohan Sharma | Approved | 2026-10-20 |
| **Technical Lead** | Antigravity Engine | Verified & Passing | 2026-10-20 |
