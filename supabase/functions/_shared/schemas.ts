// Centralized Zod validation schemas for all Edge Functions
import { z } from "zod";

export const uuidSchema = z.string().uuid("Invalid UUID format");

export const phoneSchema = z
  .string()
  .min(8, "Phone number is too short")
  .max(20, "Phone number is too long");

// 1. Staff Management
export const createStaffSchema = z.object({
  email: z.string().email("Invalid email address"),
  fullName: z.string().min(2, "Full name must be at least 2 characters"),
  role: z.enum(["owner", "doctor", "receptionist"]),
});

export const toggleStaffStatusSchema = z.object({
  userId: uuidSchema,
  active: z.boolean(),
});

export const updateStaffRoleSchema = z.object({
  userId: uuidSchema,
  role: z.enum(["owner", "doctor", "receptionist"]),
});

// 2. AI Prescription Extraction
export const extractPrescriptionSchema = z.object({
  patientId: uuidSchema,
  imageBase64: z.string().min(10, "Base64 image content is required"),
  mimeType: z.enum(["image/jpeg", "image/png", "image/webp", "application/pdf"]).default("image/jpeg"),
});

export const medicineItemSchema = z.object({
  name: z.string().min(1, "Medicine name is required"),
  dosage: z.string().default("1 dose"),
  frequency: z.string().default("Once daily"),
  duration_days: z.number().int().positive().default(5),
  instructions: z.string().default("After meals"),
  confidence: z.number().min(0).max(1).optional(),
});

export const geminiExtractionResponseSchema = z.object({
  medicines: z.array(medicineItemSchema),
  follow_up_days: z.number().int().min(0).max(365).optional(),
  clinical_notes: z.string().optional(),
  warnings: z.array(z.string()).default([]),
});

// 3. Appointment Confirmation (Public)
export const confirmAppointmentSchema = z.object({
  token: z.string().min(16, "Token must be valid"),
  action: z.enum(["confirm", "reschedule"]),
  preferred_date: z.string().optional(), // YYYY-MM-DD
  notes: z.string().max(500).optional(),
});

// 4. Slots & Booking
export const getSlotsSchema = z.object({
  doctorId: uuidSchema,
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Date must be YYYY-MM-DD"),
});

export const bookSlotSchema = z.object({
  patientId: uuidSchema,
  doctorId: uuidSchema,
  startsAt: z.string().datetime("startsAt must be an ISO-8601 timestamp"),
  notes: z.string().max(500).optional(),
});

// 5. Direct Message & Retries
export const sendDirectMessageSchema = z.object({
  patientId: uuidSchema,
  body: z.string().min(1).max(2000),
  channel: z.enum(["whatsapp", "sms"]).default("whatsapp"),
  isTemplate: z.boolean().default(false),
  templateName: z.string().optional(),
  templateVariables: z.record(z.string()).optional(),
});

export const retryNotificationSchema = z.object({
  notificationId: uuidSchema,
});

// 6. Recall
export const recallListSchema = z.object({
  unseenMonths: z.number().int().min(1).max(36).default(6),
  filterRiskPlans: z.boolean().default(true),
  filterOverdueFollowups: z.boolean().default(true),
});

export const sendRecallSchema = z.object({
  patientIds: z.array(uuidSchema).min(1, "At least one patient must be selected"),
  templateText: z.string().min(5, "Template text is required"),
  campaignName: z.string().min(2, "Campaign name is required"),
});

// 7. Treatment Plans
export const createPlanFromTemplateSchema = z.object({
  patientId: uuidSchema,
  doctorId: uuidSchema,
  templateId: uuidSchema,
  customTitle: z.string().optional(),
});

export const completeStageSchema = z.object({
  stageId: uuidSchema,
  clinicalNotes: z.string().optional(),
  confirmNextAppointment: z.boolean().default(true),
});

export const stageActionSchema = z.object({
  stageId: uuidSchema,
  notes: z.string().optional(),
});

export const planActionSchema = z.object({
  planId: uuidSchema,
});

// 8. Medication Reminders
export const generateMedicationScheduleSchema = z.object({
  prescriptionId: uuidSchema,
  patientId: uuidSchema,
  doctorId: uuidSchema,
  schedules: z.array(
    z.object({
      medicineName: z.string().min(1),
      dosage: z.string(),
      timing: z.array(z.string()),
      startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    })
  ),
});

// 9. Data Subject Tools
export const exportPatientDataSchema = z.object({
  patientId: uuidSchema,
});

export const erasePatientDataSchema = z.object({
  patientId: uuidSchema,
  confirmConfirmationPhrase: z.literal("PERMANENTLY DELETE PATIENT DATA"),
});
