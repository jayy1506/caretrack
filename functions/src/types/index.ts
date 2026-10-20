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
  slug?: string; // unique slug e.g. "smile-dental" for public booking /book/:slug
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

export interface ScheduleBreak {
  start: string; // "13:00" or "01:00 PM"
  end: string;   // "14:00" or "02:00 PM"
  name?: string;
}

export interface DayAvailability {
  start: string; // "09:00 AM"
  end: string;   // "06:00 PM"
  isOpen: boolean;
}

export interface DoctorSchedule {
  weeklyHours: Record<string, DayAvailability>; // 'monday' ... 'sunday'
  breaks: ScheduleBreak[];
  slotDurationMinutes: number; // e.g. 30
  leaveDays: string[]; // YYYY-MM-DD
}

export interface UserDocument {
  uid: string;
  name: string;
  email: string;
  phone?: string;
  role: UserRole;
  clinicId?: string;
  specialty?: string;
  schedule?: DoctorSchedule;
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
  allergies?: string[];
  preferredReminderHour?: number; // 8 to 21 (IST)
  pastResponseHours?: number[];
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
  bookingSource?: 'online' | 'reception' | 'doctor';
  verificationTokenHash?: string;
  verificationTokenExpiresAt?: FirebaseFirestore.Timestamp | Date | string;
  rescheduleReason?: string;
  reminder24hSent: boolean;
  lastReminderSentAt?: FirebaseFirestore.Timestamp | Date | string;
  riskScore?: number; // 0.0 to 1.0
  riskLevel?: 'low' | 'medium' | 'high';
  riskFactors?: string[];
  extraReminderSent?: boolean;
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
  entityType: 'patient' | 'prescription' | 'appointment' | 'staff' | 'clinic' | 'plan' | 'ai' | 'conversation';
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

export interface ConversationMessage {
  id: string;
  sender: 'patient' | 'clinic';
  text: string;
  timestamp: FirebaseFirestore.Timestamp | Date | string;
  status: 'sent' | 'delivered' | 'read' | 'failed';
  channel: 'whatsapp' | 'email' | 'sms';
  isUrgent?: boolean;
  urgentReasons?: string[];
  templateName?: string;
}

export interface ConversationThread {
  id: string; // patientId
  clinicId: string;
  patientId: string;
  patientName: string;
  patientPhone: string;
  lastMessageText: string;
  lastMessageAt: FirebaseFirestore.Timestamp | Date | string;
  unreadCount: number;
  isUrgent: boolean;
  assignedStaffId?: string;
  status: 'open' | 'resolved';
  lastUserInboundAt?: FirebaseFirestore.Timestamp | Date | string;
}

export interface RecallCampaignDocument {
  id: string;
  clinicId: string;
  name: string;
  templateName: string;
  targetCount: number;
  sentCount: number;
  skippedConsentCount: number;
  skippedRecentCount: number;
  repliedCount: number;
  bookedCount: number;
  createdAt: FirebaseFirestore.Timestamp | Date | string;
  status: 'running' | 'completed';
}

export type MedicationWindow = 'morning' | 'afternoon' | 'night';

export interface MedicationScheduleItem {
  medicineName: string;
  dosage: string; // e.g. "500mg" or "1 tablet"
  frequency: string; // e.g. "BD", "Twice daily"
  timing: MedicationWindow[];
  instructions?: string; // e.g. "After food"
  durationDays: number;
}

export interface MedicationTimeWindows {
  morning: string;   // e.g. "08:30 AM"
  afternoon: string; // e.g. "01:30 PM"
  night: string;     // e.g. "08:30 PM"
}

export interface MedicationAdherence {
  totalReminders: number;
  takenCount: number;
  missedCount: number;
  adherenceRate: number; // 0 to 100 percentage
}

export interface MedicationScheduleDocument {
  id: string;
  clinicId: string;
  patientId: string;
  doctorId: string;
  prescriptionId: string;
  status: 'draft' | 'active' | 'completed' | 'paused' | 'cancelled';
  startDate: string; // YYYY-MM-DD
  endDate: string;   // YYYY-MM-DD
  timeWindows: MedicationTimeWindows;
  items: MedicationScheduleItem[];
  adherence: MedicationAdherence;
  doctorConfirmed: boolean;
  confirmedAt?: FirebaseFirestore.Timestamp | Date | string;
  createdAt: FirebaseFirestore.Timestamp | Date | string;
  updatedAt: FirebaseFirestore.Timestamp | Date | string;
}

export interface MedicationReminderLog {
  id: string;
  scheduleId: string;
  clinicId: string;
  patientId: string;
  doctorId: string;
  date: string; // YYYY-MM-DD
  window: MedicationWindow;
  scheduledTime: string;
  status: 'scheduled' | 'sent' | 'taken' | 'missed' | 'skipped_no_consent' | 'failed';
  medicinesSummary: string;
  tokenHash?: string;
  sentAt?: FirebaseFirestore.Timestamp | Date | string;
  takenAt?: FirebaseFirestore.Timestamp | Date | string;
  createdAt: FirebaseFirestore.Timestamp | Date | string;
}

export type SafetyWarningType = 'allergy_conflict' | 'duplicate_drug' | 'duplicate_drug_class';

export interface PrescriptionSafetyWarning {
  type: SafetyWarningType;
  severity: 'danger' | 'warning';
  medicineName: string;
  conflictingItem?: string;
  message: string;
  clinicalRationale: string;
}

export interface PrescriptionSafetyCheckResult {
  hasWarnings: boolean;
  warnings: PrescriptionSafetyWarning[];
  patientAllergiesChecked: string[];
}

export interface ClinicFaqDocument {
  id: string;
  clinicId: string;
  title: string;
  category: 'timings' | 'location' | 'services' | 'faq' | 'policy';
  content: string;
  keywords: string[];
  updatedAt: FirebaseFirestore.Timestamp | Date | string;
}

export interface FaqQueryResult {
  answer: string;
  citations: string[];
  isClinicalHandoff: boolean;
  isGrounded: boolean;
  confidence: number;
}



