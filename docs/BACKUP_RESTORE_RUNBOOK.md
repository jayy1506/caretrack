# CareTrack Disaster Recovery: Firestore Backup & Restore Runbook

This document details the automated backup schedule, retention, and exact emergency restoration procedures for CareTrack's multi-clinic Firestore database.

---

## 1. Automated Daily Backups

- **Trigger Function**: `scheduledFirestoreBackup` (Google Cloud Functions v2 Scheduler).
- **Cadence**: Daily at `02:00 AM IST` (`0 2 * * *`, Asia/Kolkata).
- **Target Bucket**: `gs://${PROJECT_ID}-backups/firestore-backups/${TIMESTAMP}`
- **Collections Included**:
  - `clinics`
  - `users`
  - `patients`
  - `prescriptions`
  - `appointments`
  - `notifications`
  - `treatmentPlans`
  - `auditLogs`

### Backup Lifecycle & Retention
- **Retention Period**: 90 days.
- **Storage Class**: Nearline for the first 30 days, transitioning to Coldline for days 31–90 via Cloud Storage Object Lifecycle Management.

---

## 2. Emergency Point-in-Time Restore Procedure

When recovering from an accidental mass deletion, data corruption, or disaster scenario, follow these steps:

### Step 1: Identify Backup Location
Find the most recent healthy backup snapshot in Google Cloud Storage:
```bash
gcloud storage ls gs://${PROJECT_ID}-backups/firestore-backups/
```
Example path: `gs://caretrack-prod-backups/firestore-backups/2026-10-20T02-00-00-000Z`

### Step 2: Set Project Context
Ensure you are operating against the targeted Firebase project:
```bash
# Verify active project
firebase use production
gcloud config set project caretrack-prod
```

### Step 3: Execute Restoration Command
Run the `gcloud firestore import` command pointing to the snapshot URI prefix:
```bash
# Full restore of all collections:
gcloud firestore import gs://caretrack-prod-backups/firestore-backups/2026-10-20T02-00-00-000Z

# Or restore specific collections (e.g. only patients and appointments):
gcloud firestore import gs://caretrack-prod-backups/firestore-backups/2026-10-20T02-00-00-000Z \
  --collection-ids='patients','appointments'
```

### Step 4: Monitor Import Operation Progress
```bash
# Track operation status
gcloud firestore operations list
```

### Step 5: Post-Restore Verification Checklist
1. Inspect Firestore console to verify collection document counts.
2. Run database integrity checks:
   ```bash
   npm --prefix functions run test
   ```
3. Test doctor login and verify that patients, prescriptions, and appointment history render without errors.
4. Verify custom claims and clinic assignment.

---

## 3. Point-in-Time Recovery (PITR)

CareTrack production database has 7-day continuous PITR enabled:
```bash
# Enable PITR on production database
gcloud firestore databases update --database='(default)' --enable-pitr
```
To recover data from a specific minute in the past 7 days without restoring from a daily snapshot:
```bash
gcloud firestore databases restore \
  --source-database='(default)' \
  --destination-database='caretrack-recovery' \
  --recovery-time='2026-10-20T10:30:00Z'
```
