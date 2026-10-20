import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import { z } from 'zod';
import { db, COLLECTIONS } from '../config/index.js';
import {
  TreatmentPlanDocument,
  TreatmentPlanStage,
  TreatmentPlanStatus,
  AppointmentDocument,
  PatientDocument,
  ClinicDocument,
} from '../types/index.js';
import { FollowUpService } from '../services/followUpService.js';
import { AuditService } from '../services/auditService.js';
import { NotificationService } from '../services/notificationService.js';

// Pre-seeded Clinic Dental Plan Templates
export const DEFAULT_DENTAL_TEMPLATES = [
  {
    id: 'tpl_rct_3',
    title: 'Root Canal Treatment (RCT - 3 Sittings)',
    description: 'Standard 3-sitting endodontic therapy with BMP, shaping, and obturation',
    stages: [
      { order: 1, name: 'Access Opening & Biomechanical Preparation (BMP)', intervalDaysFromPrevious: 0, notes: 'Pulpectomy and canal length estimation' },
      { order: 2, name: 'Canal Disinfection, Cleaning & Shaping', intervalDaysFromPrevious: 5, notes: 'Intracanal medicament check' },
      { order: 3, name: 'Canal Obturation & Permanent Core Build-up', intervalDaysFromPrevious: 7, notes: 'Gutta-percha obturation and post-endodontic seal' },
    ],
  },
  {
    id: 'tpl_braces_monthly',
    title: 'Orthodontic Braces Alignment (Monthly Stages)',
    description: 'Comprehensive fixed orthodontic adjustment and wire progression schedule',
    stages: [
      { order: 1, name: 'Bonding & Initial Archwire Placement', intervalDaysFromPrevious: 0, notes: 'Bracket placement and oral hygiene protocol' },
      { order: 2, name: 'Archwire Progression & Alignment Review', intervalDaysFromPrevious: 30, notes: 'Wire change and bracket check' },
      { order: 3, name: 'Torque & Detailing Adjustment', intervalDaysFromPrevious: 30, notes: 'Space closure and occlusion verification' },
      { order: 4, name: 'De-bonding & Retainer Delivery', intervalDaysFromPrevious: 30, notes: 'Impression for vacuum-formed retainers' },
    ],
  },
  {
    id: 'tpl_scaling_routine',
    title: 'Preventive Teeth Scaling & Gingival Recall',
    description: 'Routine periodontal prophylaxis and 6-month preventive maintenance',
    stages: [
      { order: 1, name: 'Ultrasonic Scaling & Polishing', intervalDaysFromPrevious: 0, notes: 'Calculus removal and stain polishing' },
      { order: 2, name: '6-Month Routine Preventive Recall Scaling', intervalDaysFromPrevious: 180, notes: 'Periodontal pocket screening and maintenance' },
    ],
  },
  {
    id: 'tpl_implant_multiphase',
    title: 'Dental Implant Placement (Multi-Phase)',
    description: 'Surgical implant fixture, healing period, and final prosthetic restoration',
    stages: [
      { order: 1, name: 'Surgical Implant Fixture Placement', intervalDaysFromPrevious: 0, notes: 'Osteotomy and titanium fixture insertion' },
      { order: 2, name: 'Osseointegration Review & Suture Removal', intervalDaysFromPrevious: 14, notes: 'Soft tissue healing inspection' },
      { order: 3, name: 'Healing Abutment Placement & Impression', intervalDaysFromPrevious: 90, notes: 'Gingival former and digital scan' },
      { order: 4, name: 'Final Crown Delivery & Occlusal Verification', intervalDaysFromPrevious: 14, notes: 'Crown cementation and contact check' },
    ],
  },
  {
    id: 'tpl_extraction_7d',
    title: 'Surgical Tooth Extraction & Healing Protocol',
    description: 'Exodontia procedure followed by 7-day alveolar socket healing verification',
    stages: [
      { order: 1, name: 'Tooth Extraction & Hemostasis Protocol', intervalDaysFromPrevious: 0, notes: 'Local anesthesia, elevation, and socket compression' },
      { order: 2, name: '7-Day Suture Removal & Alveolar Socket Check', intervalDaysFromPrevious: 7, notes: 'Healing inspection and suture removal' },
    ],
  },
];

// Helper to verify caller ownership and role
async function verifyClinicStaff(requestAuth: any, clinicId: string) {
  if (!requestAuth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const callerUid = requestAuth.uid;
  const callerRole = requestAuth.token?.role;
  const callerClinicId = requestAuth.token?.clinicId;

  const callerDoc = await db.collection(COLLECTIONS.USERS).doc(callerUid).get();
  const userData = callerDoc.data();
  const role = callerRole || userData?.role || 'doctor';
  const userClinicId = callerClinicId || userData?.clinicId || 'default-clinic';

  if (role !== 'admin' && userClinicId !== clinicId) {
    throw new HttpsError('permission-denied', 'You cannot access records outside your clinic.');
  }

  return { callerUid, role, clinicId: userClinicId };
}

// 1. Get Plan Templates (pre-seeds defaults if not present)
export const getPlanTemplates = onCall({ cors: true }, async (request) => {
  const clinicId = request.data?.clinicId || request.auth?.token?.clinicId || 'default-clinic';
  await verifyClinicStaff(request.auth, clinicId);

  const snapshot = await db
    .collection(COLLECTIONS.PLAN_TEMPLATES)
    .where('clinicId', '==', clinicId)
    .get();

  if (snapshot.empty) {
    // Seed default dental templates for this clinic
    const batch = db.batch();
    const seededTemplates = [];

    for (const tpl of DEFAULT_DENTAL_TEMPLATES) {
      const docRef = db.collection(COLLECTIONS.PLAN_TEMPLATES).doc(`${clinicId}_${tpl.id}`);
      const templateData = {
        id: docRef.id,
        clinicId,
        title: tpl.title,
        description: tpl.description,
        stages: tpl.stages,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      batch.set(docRef, templateData);
      seededTemplates.push(templateData);
    }
    await batch.commit();
    return { templates: seededTemplates };
  }

  const templates = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  return { templates };
});

const CreatePlanSchema = z.object({
  clinicId: z.string().min(1, 'clinicId is required'),
  patientId: z.string().min(1, 'patientId is required'),
  templateId: z.string().optional(),
  title: z.string().min(1, 'Plan title is required'),
  firstAppointmentDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'firstAppointmentDate must be YYYY-MM-DD'),
  firstAppointmentTime: z.string().default('10:00 AM'),
  stages: z
    .array(
      z.object({
        order: z.number().int().positive(),
        name: z.string().min(1),
        intervalDaysFromPrevious: z.number().int().nonnegative(),
        notes: z.string().optional(),
      })
    )
    .optional(),
});

// 2. Create Treatment Plan From Template (Auto-creates first appointment)
export const createPlanFromTemplate = onCall({ cors: true }, async (request) => {
  const parseResult = CreatePlanSchema.safeParse(request.data);
  if (!parseResult.success) {
    throw new HttpsError('invalid-argument', parseResult.error.errors.map((e) => e.message).join(', '));
  }

  const {
    clinicId,
    patientId,
    templateId,
    title,
    firstAppointmentDate,
    firstAppointmentTime,
    stages: customStages,
  } = parseResult.data;

  const { callerUid } = await verifyClinicStaff(request.auth, clinicId);

  // Retrieve patient
  const patientDoc = await db.collection(COLLECTIONS.PATIENTS).doc(patientId).get();
  if (!patientDoc.exists) {
    throw new HttpsError('not-found', 'Patient record not found.');
  }
  const patientData = patientDoc.data() as PatientDocument;
  const doctorId = callerUid;

  // Resolve stages from template or custom stages
  let resolvedStages: Array<{ order: number; name: string; intervalDaysFromPrevious: number; notes?: string }> = [];

  if (customStages && customStages.length > 0) {
    resolvedStages = customStages;
  } else if (templateId) {
    // Look up template in Firestore or fallback to pre-seeded defaults
    const tplDoc = await db.collection(COLLECTIONS.PLAN_TEMPLATES).doc(templateId).get();
    if (tplDoc.exists) {
      resolvedStages = tplDoc.data()?.stages || [];
    } else {
      const defaultMatch = DEFAULT_DENTAL_TEMPLATES.find((t) => t.id === templateId || `${clinicId}_${t.id}` === templateId);
      if (defaultMatch) {
        resolvedStages = defaultMatch.stages;
      }
    }
  }

  if (resolvedStages.length === 0) {
    throw new HttpsError('invalid-argument', 'No stages provided or template contains zero stages.');
  }

  // Auto-create first appointment for stage 1
  const apptRef = db.collection(COLLECTIONS.APPOINTMENTS).doc();
  const stage1Name = resolvedStages[0]?.name || title;

  const firstAppt: AppointmentDocument = {
    id: apptRef.id,
    clinicId,
    doctorId,
    patientId,
    date: firstAppointmentDate,
    time: firstAppointmentTime,
    type: 'Consultation',
    reason: `${title} - Stage 1: ${stage1Name}`,
    notes: resolvedStages[0]?.notes || '',
    status: 'Scheduled',
    confirmationStatus: 'Pending',
    reminder24hSent: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
    updatedAt: admin.firestore.FieldValue.serverTimestamp() as any,
  };

  const planRef = db.collection(COLLECTIONS.TREATMENT_PLANS).doc();

  // Build stage objects with appointmentId mapped on stage 1
  const stages: TreatmentPlanStage[] = resolvedStages.map((s, idx) => ({
    order: s.order || idx + 1,
    name: s.name,
    intervalDaysFromPrevious: s.intervalDaysFromPrevious,
    appointmentId: idx === 0 ? apptRef.id : undefined,
    status: idx === 0 ? 'scheduled' : 'upcoming',
    notes: s.notes,
  }));

  const planDoc: TreatmentPlanDocument = {
    id: planRef.id,
    clinicId,
    patientId,
    doctorId,
    title,
    templateId,
    status: 'active',
    stages,
    startedAt: admin.firestore.FieldValue.serverTimestamp() as any,
    createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
    updatedAt: admin.firestore.FieldValue.serverTimestamp() as any,
  };

  const batch = db.batch();
  batch.set(apptRef, firstAppt);
  batch.set(planRef, planDoc);
  await batch.commit();

  // Audit log
  await AuditService.log({
    clinicId,
    userId: callerUid,
    action: 'treatment_plan.created',
    entityType: 'plan',
    entityId: planRef.id,
    details: { stageCount: stages.length, templateId, firstAppointmentDate },
  });

  return {
    success: true,
    planId: planRef.id,
    firstAppointmentId: apptRef.id,
    plan: planDoc,
  };
});

const CompleteStageSchema = z.object({
  planId: z.string().min(1, 'planId is required'),
  stageOrder: z.number().int().positive(),
  confirmedNextDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  confirmedNextTime: z.string().default('10:00 AM'),
  stageNotes: z.string().optional(),
});

// 3. Complete Stage (Marks stage done, auto-proposes or schedules next stage)
export const completeStage = onCall({ cors: true }, async (request) => {
  const parseResult = CompleteStageSchema.safeParse(request.data);
  if (!parseResult.success) {
    throw new HttpsError('invalid-argument', parseResult.error.errors.map((e) => e.message).join(', '));
  }

  const { planId, stageOrder, confirmedNextDate, confirmedNextTime, stageNotes } = parseResult.data;

  const planRef = db.collection(COLLECTIONS.TREATMENT_PLANS).doc(planId);
  const planDoc = await planRef.get();
  if (!planDoc.exists) {
    throw new HttpsError('not-found', 'Treatment plan not found.');
  }

  const plan = planDoc.data() as TreatmentPlanDocument;
  const { callerUid } = await verifyClinicStaff(request.auth, plan.clinicId);

  // Retrieve clinic configuration to access holidays and working hours
  const clinicDoc = await db.collection(COLLECTIONS.CLINICS).doc(plan.clinicId).get();
  const clinic = clinicDoc.data() as ClinicDocument | undefined;
  const holidays = clinic?.holidays || [];

  const stages = [...plan.stages];
  const targetStageIdx = stages.findIndex((s) => s.order === stageOrder);
  if (targetStageIdx === -1) {
    throw new HttpsError('not-found', `Stage ${stageOrder} not found in this plan.`);
  }

  // Idempotency: if already marked done, return gracefully
  if (stages[targetStageIdx].status === 'done') {
    return { success: true, message: 'Stage was already completed.', plan };
  }

  // Mark current stage done
  stages[targetStageIdx].status = 'done';
  if (stageNotes) {
    stages[targetStageIdx].notes = stageNotes;
  }

  // Mark associated appointment as Completed if present
  if (stages[targetStageIdx].appointmentId) {
    await db
      .collection(COLLECTIONS.APPOINTMENTS)
      .doc(stages[targetStageIdx].appointmentId!)
      .update({
        status: 'Completed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      })
      .catch((_) => {});
  }

  // Look for next upcoming stage
  const nextStageIdx = stages.findIndex((s) => s.order > stageOrder && s.status !== 'done' && s.status !== 'skipped');

  let proposedNextDate: string | null = null;
  let nextApptId: string | null = null;

  if (nextStageIdx !== -1) {
    const nextStage = stages[nextStageIdx];
    const todayStr = FollowUpService.formatDate(new Date());

    // Auto-propose date using followUpService
    proposedNextDate = FollowUpService.proposeNextStageDate(
      todayStr,
      nextStage.intervalDaysFromPrevious || 7,
      { skipSundays: true, holidays }
    );

    // If doctor confirmed the next date, create the appointment as Pending
    const finalNextDate = confirmedNextDate || proposedNextDate;
    const nextApptRef = db.collection(COLLECTIONS.APPOINTMENTS).doc();

    const nextAppt: AppointmentDocument = {
      id: nextApptRef.id,
      clinicId: plan.clinicId,
      doctorId: plan.doctorId,
      patientId: plan.patientId,
      date: finalNextDate,
      time: confirmedNextTime,
      type: 'Follow-up',
      reason: `${plan.title} - Stage ${nextStage.order}: ${nextStage.name}`,
      notes: nextStage.notes || '',
      status: 'Scheduled',
      confirmationStatus: 'Pending',
      reminder24hSent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
      updatedAt: admin.firestore.FieldValue.serverTimestamp() as any,
    };

    await nextApptRef.set(nextAppt);
    nextApptId = nextApptRef.id;

    stages[nextStageIdx].appointmentId = nextApptId;
    stages[nextStageIdx].status = 'scheduled';
  }

  // Check if all stages are now completed
  const allCompleted = stages.every((s) => s.status === 'done' || s.status === 'skipped');
  const newStatus: TreatmentPlanStatus = allCompleted ? 'completed' : 'active';

  await planRef.update({
    stages,
    status: newStatus,
    completedAt: allCompleted ? admin.firestore.FieldValue.serverTimestamp() : null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Audit log
  await AuditService.log({
    clinicId: plan.clinicId,
    userId: callerUid,
    action: 'treatment_plan.stage_completed',
    entityType: 'plan',
    entityId: planId,
    details: { completedStageOrder: stageOrder, nextStageAppointmentId: nextApptId },
  });

  return {
    success: true,
    message: allCompleted ? 'Treatment plan completed!' : `Stage ${stageOrder} completed. Next stage scheduled.`,
    completedStageOrder: stageOrder,
    proposedNextDate,
    nextAppointmentId: nextApptId,
    planStatus: newStatus,
  };
});

const SkipStageSchema = z.object({
  planId: z.string().min(1, 'planId is required'),
  stageOrder: z.number().int().positive(),
  reason: z.string().optional(),
});

// 4. Skip Stage
export const skipStage = onCall({ cors: true }, async (request) => {
  const parseResult = SkipStageSchema.safeParse(request.data);
  if (!parseResult.success) {
    throw new HttpsError('invalid-argument', parseResult.error.errors.map((e) => e.message).join(', '));
  }

  const { planId, stageOrder, reason } = parseResult.data;
  const planRef = db.collection(COLLECTIONS.TREATMENT_PLANS).doc(planId);
  const planDoc = await planRef.get();
  if (!planDoc.exists) {
    throw new HttpsError('not-found', 'Treatment plan not found.');
  }

  const plan = planDoc.data() as TreatmentPlanDocument;
  const { callerUid } = await verifyClinicStaff(request.auth, plan.clinicId);

  const stages = [...plan.stages];
  const targetStageIdx = stages.findIndex((s) => s.order === stageOrder);
  if (targetStageIdx === -1) {
    throw new HttpsError('not-found', `Stage ${stageOrder} not found.`);
  }

  stages[targetStageIdx].status = 'skipped';
  if (reason) {
    stages[targetStageIdx].notes = `${stages[targetStageIdx].notes || ''} [Skipped: ${reason}]`.trim();
  }

  const allCompleted = stages.every((s) => s.status === 'done' || s.status === 'skipped');
  const newStatus: TreatmentPlanStatus = allCompleted ? 'completed' : 'active';

  await planRef.update({
    stages,
    status: newStatus,
    completedAt: allCompleted ? admin.firestore.FieldValue.serverTimestamp() : null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await AuditService.log({
    clinicId: plan.clinicId,
    userId: callerUid,
    action: 'treatment_plan.stage_skipped',
    entityType: 'plan',
    entityId: planId,
    details: { stageOrder, reason },
  });

  return { success: true, message: `Stage ${stageOrder} skipped.`, stages, planStatus: newStatus };
});

const PlanActionSchema = z.object({
  planId: z.string().min(1, 'planId is required'),
  reason: z.string().optional(),
});

// 5. Pause Plan
export const pausePlan = onCall({ cors: true }, async (request) => {
  const parseResult = PlanActionSchema.safeParse(request.data);
  if (!parseResult.success) {
    throw new HttpsError('invalid-argument', parseResult.error.errors.map((e) => e.message).join(', '));
  }

  const { planId, reason } = parseResult.data;
  const planRef = db.collection(COLLECTIONS.TREATMENT_PLANS).doc(planId);
  const planDoc = await planRef.get();
  if (!planDoc.exists) {
    throw new HttpsError('not-found', 'Treatment plan not found.');
  }

  const plan = planDoc.data() as TreatmentPlanDocument;
  const { callerUid } = await verifyClinicStaff(request.auth, plan.clinicId);

  await planRef.update({
    status: 'paused',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await AuditService.log({
    clinicId: plan.clinicId,
    userId: callerUid,
    action: 'treatment_plan.paused',
    entityType: 'plan',
    entityId: planId,
    details: { reason },
  });

  return { success: true, message: 'Treatment plan paused.' };
});

// 6. Resume Plan
export const resumePlan = onCall({ cors: true }, async (request) => {
  const parseResult = PlanActionSchema.safeParse(request.data);
  if (!parseResult.success) {
    throw new HttpsError('invalid-argument', parseResult.error.errors.map((e) => e.message).join(', '));
  }

  const { planId } = parseResult.data;
  const planRef = db.collection(COLLECTIONS.TREATMENT_PLANS).doc(planId);
  const planDoc = await planRef.get();
  if (!planDoc.exists) {
    throw new HttpsError('not-found', 'Treatment plan not found.');
  }

  const plan = planDoc.data() as TreatmentPlanDocument;
  const { callerUid } = await verifyClinicStaff(request.auth, plan.clinicId);

  await planRef.update({
    status: 'active',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await AuditService.log({
    clinicId: plan.clinicId,
    userId: callerUid,
    action: 'treatment_plan.resumed',
    entityType: 'plan',
    entityId: planId,
  });

  return { success: true, message: 'Treatment plan resumed to active.' };
});

// 7. Mark Plan At Risk (Triggered when a stage appointment is missed)
export async function markPlanAtRiskIfMissed(appointmentId: string): Promise<boolean> {
  try {
    const plansSnapshot = await db
      .collection(COLLECTIONS.TREATMENT_PLANS)
      .where('status', 'in', ['active', 'paused'])
      .get();

    for (const doc of plansSnapshot.docs) {
      const plan = doc.data() as TreatmentPlanDocument;
      const stageWithAppt = plan.stages.find((s) => s.appointmentId === appointmentId);

      if (stageWithAppt) {
        // Mark plan as at_risk
        await doc.ref.update({
          status: 'at_risk',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Add patient to recall list
        const recallRef = db.collection(COLLECTIONS.RECALL_LIST).doc();
        await recallRef.set({
          id: recallRef.id,
          clinicId: plan.clinicId,
          patientId: plan.patientId,
          doctorId: plan.doctorId,
          reason: `Missed stage appointment for ${plan.title} (Stage: ${stageWithAppt.name})`,
          planId: doc.id,
          stageOrder: stageWithAppt.order,
          status: 'pending_recall',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await AuditService.log({
          clinicId: plan.clinicId,
          userId: 'system',
          action: 'treatment_plan.marked_at_risk',
          entityType: 'plan',
          entityId: doc.id,
          details: { missedAppointmentId: appointmentId },
        });

        return true;
      }
    }
  } catch (err) {
    console.error('Error marking plan at risk:', err);
  }
  return false;
}

/**
 * Automated Firestore Trigger: Listens to appointment status updates.
 * When an appointment transition to 'Missed' occurs, it checks if the
 * appointment was linked to a treatment plan and automatically updates
 * the plan status to 'at_risk' and appends a recall item.
 */
export const onAppointmentUpdated = onDocumentUpdated(
  'appointments/{appointmentId}',
  async (event) => {
    const beforeData = event.data?.before?.data() as AppointmentDocument | undefined;
    const afterData = event.data?.after?.data() as AppointmentDocument | undefined;
    if (!afterData) return;

    const wasMissed = beforeData?.status?.toLowerCase() === 'missed';
    const isMissed = afterData.status?.toLowerCase() === 'missed';

    if (!wasMissed && isMissed) {
      const apptId = event.params.appointmentId;
      console.log(`Appointment ${apptId} updated to Missed. Evaluating treatment plan status...`);
      await markPlanAtRiskIfMissed(apptId);
    }
  }
);
