import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';
import { db, COLLECTIONS } from '../config/index.js';
import { GeminiPrescriptionService } from '../services/geminiService.js';
import { FollowUpService } from '../services/followUpService.js';
import { PrescriptionSafetyService } from '../services/prescriptionSafetyService.js';
import { SmartTimingService } from '../services/smartTimingService.js';
import { FollowUpType, MedicineItem, PatientDocument } from '../types/index.js';

interface ExtractPrescriptionRequest {
  storagePath?: string;
  base64Data?: string;
  mimeType?: string;
}

export const extractPrescriptionData = onCall({ cors: true, timeoutSeconds: 60 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to extract prescriptions.');
  }

  const { storagePath, base64Data, mimeType } = request.data as ExtractPrescriptionRequest;

  if (!storagePath && !base64Data) {
    throw new HttpsError('invalid-argument', 'Either storagePath or base64Data is required.');
  }

  const result = await GeminiPrescriptionService.extractPrescription({
    storagePath,
    base64Data,
    mimeType,
  });

  if (!result.success || !result.data) {
    return {
      success: false,
      error: result.error || 'Could not extract prescription details.',
    };
  }

  // Calculate default follow-up date deterministically based on extracted suggestion
  const suggestedType: FollowUpType = result.data.suggestedFollowUpType || '3_months';
  const calculatedDate = FollowUpService.calculateFollowUpDate(
    result.data.prescriptionDate,
    suggestedType
  );

  return {
    success: true,
    data: {
      ...result.data,
      calculatedFollowUpDate: calculatedDate,
    },
  };
});

const CheckSafetySchema = z.object({
  clinicId: z.string().min(1),
  patientId: z.string().min(1),
  medicines: z.array(
    z.object({
      name: z.string().min(1),
      dosage: z.string().optional().default(''),
      frequency: z.string().optional().default(''),
      duration: z.string().optional().default(''),
      instructions: z.string().optional().default(''),
    })
  ),
});

/**
 * Checks prescription medicines against patient allergies and duplicate drug rules.
 */
export const checkPrescriptionSafetyCallable = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const parsed = CheckSafetySchema.safeParse(request.data);
  if (!parsed.success) {
    throw new HttpsError('invalid-argument', parsed.error.issues[0]?.message || 'Invalid parameters.');
  }

  const { clinicId, patientId, medicines } = parsed.data;

  // Retrieve patient allergies
  const patientDoc = await db.collection(COLLECTIONS.PATIENTS).doc(patientId).get();
  if (!patientDoc.exists) {
    throw new HttpsError('not-found', 'Patient record not found.');
  }

  const patientData = patientDoc.data() as PatientDocument;
  const patientAllergies = patientData.allergies || [];

  const result = PrescriptionSafetyService.checkPrescriptionSafety({
    medicines: medicines as MedicineItem[],
    patientAllergies,
  });

  return {
    success: true,
    ...result,
  };
});

const ConfirmPrescriptionSchema = z.object({
  clinicId: z.string().min(1),
  patientId: z.string().min(1),
  prescriptionId: z.string().min(1),
  medicines: z.array(
    z.object({
      name: z.string().min(1),
      dosage: z.string().optional().default(''),
      frequency: z.string().optional().default(''),
      duration: z.string().optional().default(''),
      instructions: z.string().optional().default(''),
    })
  ),
  overrideReason: z.string().optional(),
});

/**
 * Confirms prescription with safety checks, logging doctor override if warnings are bypassed.
 */
export const confirmPrescriptionWithSafety = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const parsed = ConfirmPrescriptionSchema.safeParse(request.data);
  if (!parsed.success) {
    throw new HttpsError('invalid-argument', parsed.error.issues[0]?.message || 'Invalid parameters.');
  }

  const { clinicId, patientId, prescriptionId, medicines, overrideReason } = parsed.data;
  const doctorId = request.auth.uid;

  const patientDoc = await db.collection(COLLECTIONS.PATIENTS).doc(patientId).get();
  if (!patientDoc.exists) {
    throw new HttpsError('not-found', 'Patient record not found.');
  }

  const patientData = patientDoc.data() as PatientDocument;
  const patientAllergies = patientData.allergies || [];

  const safetyResult = PrescriptionSafetyService.checkPrescriptionSafety({
    medicines: medicines as MedicineItem[],
    patientAllergies,
  });

  if (safetyResult.hasWarnings) {
    await PrescriptionSafetyService.logDoctorOverride({
      clinicId,
      doctorId,
      patientId,
      prescriptionId,
      warningCount: safetyResult.warnings.length,
      warningTypes: safetyResult.warnings.map((w) => w.type),
      overrideReason,
    });
  }

  // Update prescription record
  await db
    .collection(COLLECTIONS.PRESCRIPTIONS)
    .doc(prescriptionId)
    .update({
      doctorConfirmed: true,
      hasSafetyWarnings: safetyResult.hasWarnings,
      safetyWarningsCount: safetyResult.warnings.length,
      safetyOverrideReason: overrideReason || null,
      updatedAt: new Date().toISOString(),
    });

  return {
    success: true,
    hasWarnings: safetyResult.hasWarnings,
    warnings: safetyResult.warnings,
    overrideLogged: safetyResult.hasWarnings,
  };
});

const SmartTimingSchema = z.object({
  clinicId: z.string().min(1),
  patientId: z.string().min(1),
});

/**
 * Retrieves the optimal quiet-hours aware reminder hour for a patient.
 */
export const getOptimalReminderTiming = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const parsed = SmartTimingSchema.safeParse(request.data);
  if (!parsed.success) {
    throw new HttpsError('invalid-argument', parsed.error.issues[0]?.message || 'Invalid parameters.');
  }

  const { patientId } = parsed.data;
  const patientDoc = await db.collection(COLLECTIONS.PATIENTS).doc(patientId).get();
  if (!patientDoc.exists) {
    throw new HttpsError('not-found', 'Patient record not found.');
  }

  const patientData = patientDoc.data() as PatientDocument;
  const timingResult = SmartTimingService.getOptimalSendHour(patientData);

  return {
    success: true,
    ...timingResult,
  };
});

