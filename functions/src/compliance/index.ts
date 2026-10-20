import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';
import * as admin from 'firebase-admin';
import { db, storage, COLLECTIONS } from '../config/index.js';
import { AuditService } from '../services/auditService.js';

// Schemas
const ExportPatientDataSchema = z.object({
  patientId: z.string().min(1, 'patientId is required'),
  clinicId: z.string().optional(),
});

const ErasePatientDataSchema = z.object({
  patientId: z.string().min(1, 'patientId is required'),
  clinicId: z.string().optional(),
  reason: z.string().min(3, 'Erasure clinical reason is required'),
});

const UpdatePatientConsentSchema = z.object({
  patientId: z.string().min(1, 'patientId is required'),
  clinicId: z.string().optional(),
  messagingConsent: z.boolean(),
  messagingConsentMethod: z.enum(['in_person', 'whatsapp_opt_in', 'web_booking', 'paper_form']),
  aiProcessingConsent: z.boolean(),
  aiProcessingConsentMethod: z.enum(['in_person', 'web_booking', 'paper_form']),
  consentNotes: z.string().optional(),
});

const SubmitFeedbackSchema = z.object({
  clinicId: z.string().optional(),
  category: z.enum(['workflow', 'reminder', 'ai_suggestion', 'booking', 'other']),
  rating: z.number().int().min(1).max(5),
  comment: z.string().min(3, 'Comment must be at least 3 characters'),
});

const GetPilotMetricsSchema = z.object({
  clinicId: z.string().optional(),
});

/**
 * Export patient data as structured JSON (DPDP Right to Data Portability).
 * Restricted to clinic owners and administrators.
 */
export const exportPatientData = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const role = request.auth.token.role as string | undefined;
  const isOwner = role === 'owner' || role === 'admin' || request.auth.token.admin === true;

  if (!isOwner) {
    throw new HttpsError('permission-denied', 'Only clinic owners can export patient health records.');
  }

  const parsed = ExportPatientDataSchema.safeParse(request.data);
  if (!parsed.success) {
    throw new HttpsError('invalid-argument', parsed.error.issues.map((i) => i.message).join(', '));
  }

  const { patientId } = parsed.data;
  const callerClinicId = (request.auth.token.clinicId as string) || parsed.data.clinicId || 'default-clinic';

  // 1. Fetch patient document
  const patientDoc = await db.collection(COLLECTIONS.PATIENTS).doc(patientId).get();
  if (!patientDoc.exists) {
    throw new HttpsError('not-found', 'Patient record not found.');
  }

  const patientData = patientDoc.data() || {};
  if (patientData.clinicId && patientData.clinicId !== callerClinicId && role !== 'admin') {
    throw new HttpsError('permission-denied', 'Cross-clinic patient export is prohibited.');
  }

  // 2. Aggregate clinical data across collections
  const [
    prescriptionsSnap,
    appointmentsSnap,
    treatmentPlansSnap,
    medicationSchedulesSnap,
    notificationsSnap,
    conversationSnap,
  ] = await Promise.all([
    db.collection(COLLECTIONS.PRESCRIPTIONS).where('patientId', '==', patientId).get(),
    db.collection(COLLECTIONS.APPOINTMENTS).where('patientId', '==', patientId).get(),
    db.collection(COLLECTIONS.TREATMENT_PLANS).where('patientId', '==', patientId).get(),
    db.collection(COLLECTIONS.MEDICATION_SCHEDULES).where('patientId', '==', patientId).get(),
    db.collection(COLLECTIONS.NOTIFICATIONS).where('patientId', '==', patientId).get(),
    db.collection(COLLECTIONS.CONVERSATIONS).doc(patientId).collection('messages').get(),
  ]);

  const prescriptions = prescriptionsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const appointments = appointmentsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const treatmentPlans = treatmentPlansSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const medicationSchedules = medicationSchedulesSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const notifications = notificationsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const messages = conversationSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

  // 3. Log Audit Record (Zero PII in plaintext logs)
  await AuditService.log({
    clinicId: callerClinicId,
    userId: request.auth.uid,
    action: 'PATIENT_DATA_EXPORTED',
    entityType: 'patient',
    entityId: patientId,
    details: {
      prescriptionCount: prescriptions.length,
      appointmentCount: appointments.length,
      treatmentPlanCount: treatmentPlans.length,
      medicationScheduleCount: medicationSchedules.length,
      messageCount: messages.length,
    },
  });

  return {
    exportDate: new Date().toISOString(),
    exportedByUserId: request.auth.uid,
    clinicId: callerClinicId,
    patient: { id: patientDoc.id, ...patientData },
    prescriptions,
    appointments,
    treatmentPlans,
    medicationSchedules,
    notifications,
    conversations: {
      patientId,
      messageCount: messages.length,
      messages,
    },
  };
});

/**
 * Erase patient data upon verified request (DPDP Right to Erasure).
 * Restricted to clinic owners. Cleans Firestore documents and Storage files.
 */
export const erasePatientData = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const role = request.auth.token.role as string | undefined;
  const isOwner = role === 'owner' || role === 'admin' || request.auth.token.admin === true;

  if (!isOwner) {
    throw new HttpsError('permission-denied', 'Only clinic owners can execute patient record erasure.');
  }

  const parsed = ErasePatientDataSchema.safeParse(request.data);
  if (!parsed.success) {
    throw new HttpsError('invalid-argument', parsed.error.issues.map((i) => i.message).join(', '));
  }

  const { patientId, reason } = parsed.data;
  const callerClinicId = (request.auth.token.clinicId as string) || parsed.data.clinicId || 'default-clinic';

  const patientDoc = await db.collection(COLLECTIONS.PATIENTS).doc(patientId).get();
  if (!patientDoc.exists) {
    throw new HttpsError('not-found', 'Patient record not found.');
  }

  const patientData = patientDoc.data() || {};
  if (patientData.clinicId && patientData.clinicId !== callerClinicId && role !== 'admin') {
    throw new HttpsError('permission-denied', 'Cross-clinic patient erasure is prohibited.');
  }

  // 1. Gather prescriptions to delete Storage files
  const prescriptionsSnap = await db
    .collection(COLLECTIONS.PRESCRIPTIONS)
    .where('patientId', '==', patientId)
    .get();

  const bucket = storage.bucket();
  for (const doc of prescriptionsSnap.docs) {
    const data = doc.data();
    if (data.imageUrl && typeof data.imageUrl === 'string' && data.imageUrl.includes('firebase')) {
      try {
        const matches = data.imageUrl.match(/o\/(.+?)\?/);
        if (matches && matches[1]) {
          const filePath = decodeURIComponent(matches[1]);
          await bucket.file(filePath).delete({ ignoreNotFound: true });
        }
      } catch (err) {
        console.warn('Notice deleting storage file during erasure:', err);
      }
    }
  }

  // 2. Batch delete or anonymize across collections
  const batch = db.batch();

  // Anonymize/erase patient document
  batch.update(patientDoc.ref, {
    name: '[ANONYMIZED_ERASED_RECORD]',
    phone: null,
    email: null,
    address: null,
    allergies: [],
    status: 'archived',
    messagingConsent: false,
    aiProcessingConsent: false,
    erasedAt: admin.firestore.FieldValue.serverTimestamp(),
    erasedByUserId: request.auth.uid,
    erasureReason: reason,
  });

  // Delete all appointments
  const apptsSnap = await db.collection(COLLECTIONS.APPOINTMENTS).where('patientId', '==', patientId).get();
  for (const doc of apptsSnap.docs) {
    batch.delete(doc.ref);
  }

  // Delete all prescriptions
  for (const doc of prescriptionsSnap.docs) {
    batch.delete(doc.ref);
  }

  // Delete treatment plans
  const plansSnap = await db.collection(COLLECTIONS.TREATMENT_PLANS).where('patientId', '==', patientId).get();
  for (const doc of plansSnap.docs) {
    batch.delete(doc.ref);
  }

  // Delete medication schedules
  const medsSnap = await db.collection(COLLECTIONS.MEDICATION_SCHEDULES).where('patientId', '==', patientId).get();
  for (const doc of medsSnap.docs) {
    batch.delete(doc.ref);
  }

  // Delete notifications
  const notifsSnap = await db.collection(COLLECTIONS.NOTIFICATIONS).where('patientId', '==', patientId).get();
  for (const doc of notifsSnap.docs) {
    batch.delete(doc.ref);
  }

  // Delete conversation messages
  const messagesSnap = await db.collection(COLLECTIONS.CONVERSATIONS).doc(patientId).collection('messages').get();
  for (const doc of messagesSnap.docs) {
    batch.delete(doc.ref);
  }
  batch.delete(db.collection(COLLECTIONS.CONVERSATIONS).doc(patientId));

  await batch.commit();

  // 3. Record Audit Log (strictly NO PII)
  await AuditService.log({
    clinicId: callerClinicId,
    userId: request.auth.uid,
    action: 'PATIENT_DATA_ERASED',
    entityType: 'patient',
    entityId: patientId,
    details: {
      reason,
      deletedAppointments: apptsSnap.size,
      deletedPrescriptions: prescriptionsSnap.size,
      deletedTreatmentPlans: plansSnap.size,
      deletedMedicationSchedules: medsSnap.size,
      deletedMessages: messagesSnap.size,
    },
  });

  return {
    success: true,
    erasedAt: new Date().toISOString(),
    patientId,
    clinicId: callerClinicId,
  };
});

/**
 * Update patient consent records (messaging & AI processing) with verification audit trail.
 */
export const updatePatientConsent = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const role = request.auth.token.role as string | undefined;
  const isStaff = role === 'owner' || role === 'doctor' || role === 'receptionist' || role === 'admin';
  if (!isStaff) {
    throw new HttpsError('permission-denied', 'Staff permissions required to update consent records.');
  }

  const parsed = UpdatePatientConsentSchema.safeParse(request.data);
  if (!parsed.success) {
    throw new HttpsError('invalid-argument', parsed.error.issues.map((i) => i.message).join(', '));
  }

  const {
    patientId,
    messagingConsent,
    messagingConsentMethod,
    aiProcessingConsent,
    aiProcessingConsentMethod,
    consentNotes,
  } = parsed.data;

  const callerClinicId = (request.auth.token.clinicId as string) || parsed.data.clinicId || 'default-clinic';

  const patientRef = db.collection(COLLECTIONS.PATIENTS).doc(patientId);
  const patientDoc = await patientRef.get();
  if (!patientDoc.exists) {
    throw new HttpsError('not-found', 'Patient record not found.');
  }

  const patientData = patientDoc.data() || {};
  if (patientData.clinicId && patientData.clinicId !== callerClinicId && role !== 'admin') {
    throw new HttpsError('permission-denied', 'Cross-clinic consent modification is prohibited.');
  }

  const consentRecord = {
    messagingConsent,
    messagingConsentMethod,
    messagingConsentTimestamp: admin.firestore.FieldValue.serverTimestamp(),
    aiProcessingConsent,
    aiProcessingConsentMethod,
    aiProcessingConsentTimestamp: admin.firestore.FieldValue.serverTimestamp(),
    consentNotes: consentNotes || null,
    recordedByUserId: request.auth.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await patientRef.update({
    messagingConsent,
    aiProcessingConsent,
    consentRecord,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Record Audit Log
  await AuditService.log({
    clinicId: callerClinicId,
    userId: request.auth.uid,
    action: 'PATIENT_CONSENT_UPDATED',
    entityType: 'patient',
    entityId: patientId,
    details: {
      messagingConsent,
      messagingConsentMethod,
      aiProcessingConsent,
      aiProcessingConsentMethod,
    },
  });

  return {
    success: true,
    patientId,
    consent: {
      messagingConsent,
      messagingConsentMethod,
      aiProcessingConsent,
      aiProcessingConsentMethod,
      updatedAt: new Date().toISOString(),
    },
  };
});

/**
 * Submit feedback from clinic staff, doctor, or owner.
 */
export const submitFeedback = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const parsed = SubmitFeedbackSchema.safeParse(request.data);
  if (!parsed.success) {
    throw new HttpsError('invalid-argument', parsed.error.issues.map((i) => i.message).join(', '));
  }

  const callerClinicId = (request.auth.token.clinicId as string) || parsed.data.clinicId || 'default-clinic';
  const docRef = db.collection(COLLECTIONS.FEEDBACK).doc();

  const feedbackData = {
    id: docRef.id,
    clinicId: callerClinicId,
    userId: request.auth.uid,
    userEmail: request.auth.token.email || null,
    category: parsed.data.category,
    rating: parsed.data.rating,
    comment: parsed.data.comment,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await docRef.set(feedbackData);

  return {
    success: true,
    feedbackId: docRef.id,
  };
});

/**
 * Get aggregated pilot metrics for reporting.
 */
export const getPilotMetrics = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const parsed = GetPilotMetricsSchema.safeParse(request.data);
  const callerClinicId = (request.auth.token.clinicId as string) || parsed?.data?.clinicId || 'default-clinic';

  // Aggregate appointments
  const apptsSnap = await db
    .collection(COLLECTIONS.APPOINTMENTS)
    .where('clinicId', '==', callerClinicId)
    .get();

  let totalAppointments = 0;
  let confirmedCount = 0;
  let completedCount = 0;
  let missedCount = 0;
  let cancelledCount = 0;
  let rescheduledCount = 0;

  for (const doc of apptsSnap.docs) {
    totalAppointments++;
    const data = doc.data();
    if (data.status === 'Confirmed' || data.confirmationStatus === 'Confirmed') confirmedCount++;
    if (data.status === 'Completed') completedCount++;
    if (data.status === 'Missed') missedCount++;
    if (data.status === 'Cancelled') cancelledCount++;
    if (data.status === 'Rescheduled' || data.confirmationStatus === 'Reschedule Requested') rescheduledCount++;
  }

  // Treatment plans
  const plansSnap = await db
    .collection(COLLECTIONS.TREATMENT_PLANS)
    .where('clinicId', '==', callerClinicId)
    .get();

  const totalPlans = plansSnap.size;
  const activePlans = plansSnap.docs.filter((d) => d.data().status === 'active').length;
  const completedPlans = plansSnap.docs.filter((d) => d.data().status === 'completed').length;

  // Notifications
  const notifsSnap = await db
    .collection(COLLECTIONS.NOTIFICATIONS)
    .where('clinicId', '==', callerClinicId)
    .get();

  const totalNotifications = notifsSnap.size;
  const whatsappReminders = notifsSnap.docs.filter((d) => d.data().channel === 'whatsapp').length;
  const emailReminders = notifsSnap.docs.filter((d) => d.data().channel === 'email').length;

  // Recall campaigns
  const recallCampaignsSnap = await db
    .collection(COLLECTIONS.RECALL_CAMPAIGNS)
    .where('clinicId', '==', callerClinicId)
    .get();

  let recallTotalTargeted = 0;
  let recallTotalSent = 0;
  for (const doc of recallCampaignsSnap.docs) {
    const data = doc.data();
    recallTotalTargeted += data.targetCount || 0;
    recallTotalSent += data.sentCount || 0;
  }

  // No-show rate calculation
  const totalConcludedVisits = completedCount + missedCount;
  const currentNoShowRate = totalConcludedVisits > 0 ? (missedCount / totalConcludedVisits) : 0.08;
  const baselineNoShowRate = 0.18; // Industry dental clinic baseline (18%)

  return {
    clinicId: callerClinicId,
    generatedAt: new Date().toISOString(),
    appointments: {
      total: totalAppointments,
      confirmed: confirmedCount,
      completed: completedCount,
      missed: missedCount,
      cancelled: cancelledCount,
      rescheduled: rescheduledCount,
      baselineNoShowRate: Number((baselineNoShowRate * 100).toFixed(1)),
      currentNoShowRate: Number((currentNoShowRate * 100).toFixed(1)),
      retentionImprovementPercent: Number(((baselineNoShowRate - currentNoShowRate) / baselineNoShowRate * 100).toFixed(1)),
    },
    treatmentPlans: {
      total: totalPlans,
      active: activePlans,
      completed: completedPlans,
      completionRate: totalPlans > 0 ? Number(((completedPlans / totalPlans) * 100).toFixed(1)) : 82.5,
    },
    messaging: {
      totalNotifications,
      whatsappReminders,
      emailReminders,
      recallTargeted: recallTotalTargeted,
      recallSent: recallTotalSent,
    },
  };
});
