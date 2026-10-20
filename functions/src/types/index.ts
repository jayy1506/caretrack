export type UserRole = 'owner' | 'doctor' | 'receptionist' | 'admin';

export interface ClinicFeatureFlags {
  treatmentPlans: boolean;
  onlineBooking: boolean;
  twoWayWhatsApp: boolean;
  recall: boolean;
  medicationReminders: boolean;
  noShowAI: boolean;
  faqAssistant: boolean;
}

export interface DayWorkingHours {
  open: string; // e.g. "09:00"
  close: string; // e.g. "18:00"
  isOpen: boolean;
}

export type ClinicWorkingHours = Record<string, DayWorkingHours>;

export interface ClinicDocument {
  id: string;
  name: string;
  address: string;
  phone: string;
  timezone: string; // default "Asia/Kolkata"
  workingHours: ClinicWorkingHours;
  holidays: string[]; // YYYY-MM-DD
  logoUrl?: string;
  featureFlags: ClinicFeatureFlags;
  createdAt: FirebaseFirestore.Timestamp | Date | string;
  updatedAt: FirebaseFirestore.Timestamp | Date | string;
}

export interface UserDocument {
  uid: string;
  name: string;
  email: string;
  phone?: string;
  role: UserRole;
  clinicId?: string;
  active: boolean;
  fcmToken?: string;
  createdAt: FirebaseFirestore.Timestamp | Date | string;
  updatedAt?: FirebaseFirestore.Timestamp | Date | string;
}

export interface PatientDocument {
  id?: string;
  clinicId?: string;
  doctorId: string;
  name: string;
  age?: number;
  dateOfBirth?: string;
  phone?: string;
  email?: string;
  address?: string;
  status: 'active' | 'archived';
  messagingConsent?: boolean;
  aiProcessingConsent?: boolean;
  preferredLanguage?: 'en' | 'hi' | 'mr';
  telegramChatId?: string;
  fcmToken?: string;
  createdAt: FirebaseFirestore.Timestamp | Date | string;
  updatedAt: FirebaseFirestore.Timestamp | Date | string;
}

export interface MedicineItem {
  name: string;
  dosage: string;
  frequency: string;
  duration: string;
  instructions: string;
}

export type FollowUpType = '15_days' | '1_month' | '3_months' | '6_months' | 'custom';

export interface PrescriptionDocument {
  id?: string;
  clinicId?: string;
  doctorId: string;
  patientId: string;
  prescriptionDate: string;
  source: 'manual' | 'upload';
  originalFileUrl?: string;
  medicines: MedicineItem[];
  followUpType: FollowUpType;
  followUpDate: string;
  aiExtracted: boolean;
  doctorConfirmed: boolean;
  createdAt: FirebaseFirestore.Timestamp | Date | string;
  updatedAt?: FirebaseFirestore.Timestamp | Date | string;
}

export type AppointmentType = 'Consultation' | 'Follow-up';
export type AppointmentStatus =
  | 'pending'
  | 'confirmed'
  | 'reschedule_requested'
  | 'rescheduled'
  | 'missed'
  | 'completed'
  | 'cancelled'
  | 'Scheduled'
  | 'Confirmed'
  | 'Completed'
  | 'Missed'
  | 'Cancelled'
  | 'Rescheduled';

export type ConfirmationStatus = 'Pending' | 'Confirmed' | 'Declined' | 'Reschedule Requested';

export interface AppointmentDocument {
  id?: string;
  clinicId?: string;
  doctorId: string;
  patientId: string;
  date: string; // YYYY-MM-DD
  time: string; // HH:mm (24h or 12h format e.g. 10:00 AM)
  type: AppointmentType;
  reason?: string;
  notes?: string;
  status: AppointmentStatus;
  confirmationStatus: ConfirmationStatus;
  reminder24hSent: boolean;
  lastReminderSentAt?: FirebaseFirestore.Timestamp | Date | string;
  createdAt: FirebaseFirestore.Timestamp | Date | string;
  updatedAt: FirebaseFirestore.Timestamp | Date | string;
}

export type NotificationChannel = 'push' | 'email' | 'sms' | 'messaging' | 'whatsapp' | 'telegram';
export type NotificationType = 
  | 'patient_registration' 
  | 'appointment_confirmation' 
  | 'appointment_reminder_24h' 
  | 'appointment_reminder_demo' 
  | 'doctor_appointment_reminder'
  | 'custom_message'
  | 'followup_reminder';

export type NotificationStatus = 'sent' | 'failed' | 'skipped' | 'Pending' | 'Sent' | 'Delivered' | 'Failed';

export interface NotificationDocument {
  id?: string;
  clinicId?: string;
  doctorId: string;
  patientId?: string;
  appointmentId?: string;
  channel: NotificationChannel;
  type: NotificationType;
  recipient: string; // email, phone, or token
  scheduledFor?: FirebaseFirestore.Timestamp | Date | string;
  status: NotificationStatus;
  providerMessageId?: string;
  sentAt?: FirebaseFirestore.Timestamp | Date | string;
  error?: string;
  createdAt: FirebaseFirestore.Timestamp | Date | string;
}

export type TreatmentPlanStatus = 'active' | 'completed' | 'paused' | 'cancelled' | 'at_risk';
export type PlanStageStatus = 'upcoming' | 'scheduled' | 'done' | 'skipped';

export interface TreatmentPlanStage {
  order: number;
  name: string;
  intervalDaysFromPrevious: number;
  appointmentId?: string;
  status: PlanStageStatus;
  notes?: string;
}

export interface TreatmentPlanDocument {
  id?: string;
  clinicId: string;
  patientId: string;
  doctorId: string;
  title: string;
  templateId?: string;
  status: TreatmentPlanStatus;
  stages: TreatmentPlanStage[];
  startedAt: FirebaseFirestore.Timestamp | Date | string;
  completedAt?: FirebaseFirestore.Timestamp | Date | string;
  createdAt: FirebaseFirestore.Timestamp | Date | string;
  updatedAt: FirebaseFirestore.Timestamp | Date | string;
}

export interface AuditLogDocument {
  id?: string;
  clinicId: string;
  userId: string;
  action: string;
  entityType: 'patient' | 'prescription' | 'appointment' | 'staff' | 'clinic' | 'plan';
  entityId: string;
  details?: Record<string, any>;
  timestamp: FirebaseFirestore.Timestamp | FirebaseFirestore.FieldValue | Date | string;
}

export interface ExtractedPrescriptionResponse {
  medicines: MedicineItem[];
  prescriptionDate: string;
  followUpInstructions?: string;
  suggestedFollowUpType?: FollowUpType;
  suggestedFollowUpDays?: number;
  rawTextSummary?: string;
  confidenceNote?: string;
}
