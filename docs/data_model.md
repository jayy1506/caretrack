# CareTrack Firestore Data Model & Schema Specification

This document specifies the primary Firestore collections, subcollections, fields, data types, indexes, and access control policies in CareTrack.

---

## 1. Top-Level Collections Overview

| Collection | Purpose | Document ID | Primary Access Control |
| :--- | :--- | :--- | :--- |
| `clinics` | Clinic configuration, hours, feature flags | `clinicId` | Staff read, Owner write |
| `users` | Staff profiles & clinic affiliations | `uid` | Authenticated staff (clinic scoped) |
| `patients` | Patient demographics, DPDP consent | `patientId` | Staff read/write |
| `treatmentPlans`| Multi-stage dental treatment plans | `planId` | Doctor/Owner write, Staff read |
| `appointments` | Bookings, chair scheduling & statuses | `appointmentId` | Staff read/write, Public slot create |
| `prescriptions` | Clinical prescriptions & Rx scans | `prescriptionId` | Doctor/Owner only (Receptionist blocked) |
| `medicationSchedules` | Dose timings & intervals | `scheduleId` | Doctor/Owner write, Staff read |
| `medicationAdherence` | Dose logs & patient confirmations | `adherenceId` | Staff read/write |
| `messages` | Two-way WhatsApp inbox threads | `threadId` | Staff read/write |
| `messages/{id}/chat` | Chronological thread chat messages | `msgId` | Staff read/write |
| `auditLogs` | Zero-PII administrative audit trail | `logId` | Owner read only (Write via backend) |
| `feedback` | In-app user feedback & suggestions | `feedbackId` | Authenticated staff write, Admin read |

---

## 2. Collection Schemas

### `clinics/{clinicId}`
```typescript
interface Clinic {
  id: string; // e.g. "pilot-dental-clinic"
  name: string; // e.g. "SmileCraft Dental Studio"
  address: string;
  phone: string; // E.164 formatted clinic phone
  timezone: string; // default "Asia/Kolkata"
  workingHours: {
    [day: string]: { // monday, tuesday, etc.
      open: string;  // "09:00"
      close: string; // "19:00"
      isOpen: boolean;
    };
  };
  holidays: string[]; // ["2026-01-26", "2026-08-15"]
  logoUrl?: string;
  featureFlags: {
    treatmentPlans: boolean;
    onlineBooking: boolean;
    twoWayWhatsApp: boolean;
    recall: boolean;
    medicationReminders: boolean;
    noShowAI: boolean;
    faqAssistant: boolean;
  };
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### `users/{uid}`
```typescript
interface UserProfile {
  uid: string;
  name: string;
  email: string;
  phone?: string;
  role: 'owner' | 'doctor' | 'receptionist' | 'admin';
  clinicId: string;
  active: boolean;
  fcmToken?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### `patients/{patientId}`
```typescript
interface PatientConsentRecord {
  messagingConsent: boolean;
  messagingConsentMethod: 'in_person' | 'whatsapp_opt_in' | 'web_booking' | 'paper_form';
  messagingConsentTimestamp?: string; // ISO 8601
  aiProcessingConsent: boolean;
  aiProcessingConsentMethod: 'in_person' | 'web_booking' | 'paper_form';
  aiProcessingConsentTimestamp?: string; // ISO 8601
  consentNotes?: string;
}

interface Patient {
  id: string;
  clinicId: string;
  doctorId: string; // Assigned primary doctor UID
  name: string;
  age?: number;
  dateOfBirth?: string; // YYYY-MM-DD
  phone?: string; // E.164
  email?: string;
  address?: string;
  allergies: string[];
  preferredReminderHour?: number; // 0-23
  status: 'active' | 'archived' | 'erased';
  messagingConsent: boolean;
  aiProcessingConsent: boolean;
  consentRecord: PatientConsentRecord;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### `treatmentPlans/{planId}`
```typescript
interface TreatmentPlanStage {
  stageNumber: number;
  name: string; // e.g. "Pulpectomy & Canal Debridement"
  status: 'pending' | 'scheduled' | 'in_progress' | 'completed';
  scheduledDate?: string; // YYYY-MM-DD
  scheduledTime?: string; // e.g. "10:30 AM"
  completedAt?: string; // ISO 8601
  recommendedIntervalDays: number; // e.g. 3
  clinicalNotes?: string;
}

interface TreatmentPlan {
  id: string;
  clinicId: string;
  patientId: string;
  doctorId: string;
  title: string; // e.g. "Root Canal Treatment & Zirconia Crown"
  status: 'active' | 'in_progress' | 'completed' | 'abandoned';
  stages: TreatmentPlanStage[];
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### `appointments/{appointmentId}`
```typescript
interface Appointment {
  id: string;
  clinicId: string;
  doctorId: string;
  patientId: string;
  date: string; // YYYY-MM-DD
  time: string; // "10:30 AM"
  type: string; // "Root Canal", "Consultation", etc.
  reason?: string;
  status: 'pending' | 'confirmed' | 'reschedule_requested' | 'completed' | 'missed' | 'cancelled';
  treatmentPlanId?: string;
  treatmentPlanStageNumber?: number;
  rescheduleRequestedSlot?: string;
  reminderSent?: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### `prescriptions/{prescriptionId}`
```typescript
interface PrescriptionMedicine {
  name: string;
  dosage: string; // "500mg"
  frequency: string; // "Thrice daily"
  instructions: string; // "After meals"
  durationDays?: number;
}

interface Prescription {
  id: string;
  clinicId: string;
  doctorId: string;
  patientId: string;
  date: string; // YYYY-MM-DD
  medicines: PrescriptionMedicine[];
  instructions?: string;
  fileUrl?: string; // Cloud Storage Rx scan
  followUpDate?: string;
  suggestedRecallDays?: number;
  createdAt: Timestamp;
}
```

### `medicationSchedules/{scheduleId}` & `medicationAdherence/{adherenceId}`
```typescript
interface MedicationSchedule {
  id: string;
  clinicId: string;
  patientId: string;
  doctorId: string;
  prescriptionId?: string;
  medicines: {
    name: string;
    dosage: string;
    frequency: string;
    instructions: string;
    timesPerDay: string[]; // ["08:00", "14:00", "20:00"]
  }[];
  startDate: string; // YYYY-MM-DD
  endDate: string; // YYYY-MM-DD
  active: boolean;
  createdAt: Timestamp;
}

interface MedicationAdherence {
  id: string;
  clinicId: string;
  scheduleId: string;
  patientId: string;
  medicineName: string;
  scheduledTime: string; // "08:00"
  status: 'taken' | 'missed' | 'skipped';
  takenAt?: string; // ISO 8601
  timestamp: Timestamp;
}
```

### `messages/{threadId}` & `messages/{threadId}/chat/{msgId}`
```typescript
interface MessageThread {
  id: string; // e.g. "thread-priya-aligners"
  clinicId: string;
  patientId: string;
  patientPhone: string;
  patientName: string;
  lastMessage: string;
  lastMessageTime: string;
  unreadCount: number;
  triageStatus: 'routine' | 'urgent' | 'emergency';
  updatedAt: Timestamp;
}

interface ChatMessage {
  id: string;
  clinicId: string;
  sender: 'patient' | 'clinic' | 'system';
  senderName: string;
  text: string;
  timestamp: string; // ISO 8601
  createdAt: Timestamp;
}
```

### `auditLogs/{logId}`
```typescript
interface AuditLog {
  id: string;
  clinicId: string;
  actorUid: string;
  actorRole: string;
  action: 'PATIENT_DATA_EXPORTED' | 'PATIENT_DATA_ERASED' | 'PATIENT_CONSENT_UPDATED' | 'STAFF_ROLE_CHANGED';
  targetType: 'patient' | 'user' | 'clinic';
  targetId: string; // Scrubbed of PII
  details: Record<string, any>; // Strictly sanitized, zero PII
  timestamp: Timestamp;
}
```

---

## 3. Firestore Compound Indexes

The following compound indexes are defined in `firestore.indexes.json`:
1. `appointments`: `clinicId` (ASC), `date` (ASC), `time` (ASC)
2. `appointments`: `clinicId` (ASC), `status` (ASC), `date` (ASC)
3. `treatmentPlans`: `clinicId` (ASC), `status` (ASC), `updatedAt` (DESC)
4. `messages`: `clinicId` (ASC), `updatedAt` (DESC)
5. `auditLogs`: `clinicId` (ASC), `timestamp` (DESC)
