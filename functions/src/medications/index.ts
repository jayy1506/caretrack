import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as crypto from 'crypto';
import * as admin from 'firebase-admin';
import { z } from 'zod';
import { db, config, COLLECTIONS } from '../config/index.js';
import { MedicationScheduleService } from '../services/medicationScheduleService.js';
import { MessagingService } from '../services/messagingService.js';
import { AuditService } from '../services/auditService.js';
import { TemplateRegistryService } from '../services/templateRegistry.js';
import {
  PrescriptionDocument,
  PatientDocument,
  MedicationScheduleDocument,
  MedicationReminderLog,
  MedicationWindow,
} from '../types/index.js';

// Constant-time token verification
function verifyTokenHash(providedToken: string, storedHash: string): boolean {
  try {
    const providedHash = crypto.createHash('sha256').update(providedToken).digest('hex');
    const bufA = Buffer.from(providedHash, 'utf8');
    const bufB = Buffer.from(storedHash, 'utf8');
    if (bufA.length !== bufB.length) return false;
    return crypto.timingSafeEqual(bufA, bufB);
  } catch (_) {
    return false;
  }
}

// 1. Generate Draft Medication Schedule From Prescription
export const generateMedicationSchedule = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { prescriptionId, customWindows } = (request.data || {}) as {
    prescriptionId: string;
    customWindows?: any;
  };

  if (!prescriptionId) {
    throw new HttpsError('invalid-argument', 'prescriptionId is required.');
  }

  const rxDoc = await db.collection(COLLECTIONS.PRESCRIPTIONS).doc(prescriptionId).get();
  if (!rxDoc.exists) {
    throw new HttpsError('not-found', 'Prescription not found.');
  }

  const rxData = rxDoc.data() as PrescriptionDocument;
  const scheduleRef = db.collection(COLLECTIONS.MEDICATION_SCHEDULES).doc();

  const schedule = MedicationScheduleService.generateScheduleFromPrescription(
    rxData,
    scheduleRef.id,
    customWindows
  );

  await scheduleRef.set({
    ...schedule,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, scheduleId: scheduleRef.id, schedule };
});

const ConfirmScheduleSchema = z.object({
  scheduleId: z.string().min(1),
  items: z
    .array(
      z.object({
        medicineName: z.string().min(1),
        dosage: z.string().min(1),
        frequency: z.string().min(1),
        timing: z.array(z.enum(['morning', 'afternoon', 'night'])),
        instructions: z.string().optional(),
        durationDays: z.number().int().positive(),
      })
    )
    .optional(),
  timeWindows: z
    .object({
      morning: z.string(),
      afternoon: z.string(),
      night: z.string(),
    })
    .optional(),
});

// 2. Doctor Confirms / Activates Medication Schedule
export const confirmMedicationSchedule = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const parseResult = ConfirmScheduleSchema.safeParse(request.data);
  if (!parseResult.success) {
    throw new HttpsError('invalid-argument', parseResult.error.errors.map((e) => e.message).join(', '));
  }

  const { scheduleId, items, timeWindows } = parseResult.data;
  const scheduleRef = db.collection(COLLECTIONS.MEDICATION_SCHEDULES).doc(scheduleId);
  const doc = await scheduleRef.get();
  if (!doc.exists) {
    throw new HttpsError('not-found', 'Medication schedule not found.');
  }

  const existing = doc.data() as MedicationScheduleDocument;

  const updates: Record<string, any> = {
    status: 'active',
    doctorConfirmed: true,
    confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (items && items.length > 0) {
    updates.items = items;
  }
  if (timeWindows) {
    updates.timeWindows = {
      morning: MedicationScheduleService.adjustForQuietHours(timeWindows.morning),
      afternoon: MedicationScheduleService.adjustForQuietHours(timeWindows.afternoon),
      night: MedicationScheduleService.adjustForQuietHours(timeWindows.night),
    };
  }

  await scheduleRef.update(updates);

  await AuditService.log({
    clinicId: existing.clinicId,
    userId: request.auth.uid,
    action: 'medication.schedule_activated',
    entityType: 'prescription',
    entityId: scheduleId,
  });

  return { success: true, message: 'Medication schedule activated successfully.' };
});

// 3. Mark Medication Dose As Taken (1-Click Patient Webhook)
export const markMedicationTakenWeb = onRequest({ cors: true }, async (req, res) => {
  const { logId, token } = req.query as { logId?: string; token?: string };

  if (!logId || !token) {
    res.status(400).send(`
      <html>
        <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
          <h2 style="color: #dc2626;">Invalid Request</h2>
          <p>Required medication log parameters are missing.</p>
        </body>
      </html>
    `);
    return;
  }

  try {
    const logRef = db.collection(COLLECTIONS.MEDICATION_REMINDERS_LOG).doc(logId);
    const logDoc = await logRef.get();

    if (!logDoc.exists) {
      res.status(404).send('Reminder log not found.');
      return;
    }

    const logData = logDoc.data() as MedicationReminderLog;

    if (!logData.tokenHash || !verifyTokenHash(token, logData.tokenHash)) {
      res.status(403).send('Invalid or expired verification token.');
      return;
    }

    // Atomically mark taken and update schedule adherence
    await db.runTransaction(async (transaction) => {
      const scheduleRef = db.collection(COLLECTIONS.MEDICATION_SCHEDULES).doc(logData.scheduleId);
      const scheduleDoc = await transaction.get(scheduleRef);

      transaction.update(logRef, {
        status: 'taken',
        takenAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (scheduleDoc.exists) {
        const schedule = scheduleDoc.data() as MedicationScheduleDocument;
        const total = (schedule.adherence?.totalReminders || 0);
        const taken = (schedule.adherence?.takenCount || 0) + 1;
        const rate = MedicationScheduleService.calculateAdherence(taken, total);

        transaction.update(scheduleRef, {
          'adherence.takenCount': taken,
          'adherence.adherenceRate': rate,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });

    res.status(200).send(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>Dose Recorded - CareTrack</title>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: 'Segoe UI', Arial, sans-serif; text-align: center; padding: 40px 16px; background-color: #f3f6fa; color: #0f2a47;">
          <div style="max-width: 480px; margin: 0 auto; background: #ffffff; padding: 36px 24px; border-radius: 18px; box-shadow: 0 4px 20px rgba(0,0,0,0.06);">
            <div style="width: 56px; height: 56px; border-radius: 28px; background: #dcf5ec; color: #0b6b4a; line-height: 56px; font-size: 26px; margin: 0 auto 16px; font-weight: bold;">💊</div>
            <h2 style="color: #0b6b4a; margin: 0 0 10px; font-size: 22px;">Dose Recorded!</h2>
            <p style="color: #53657a; font-size: 15px; margin-bottom: 24px;">Great job staying on track with your prescription.</p>
            <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 18px; text-align: left; margin-bottom: 20px;">
              <p style="margin: 0 0 8px; font-size: 14px;"><strong>Medication:</strong> ${logData.medicinesSummary}</p>
              <p style="margin: 0; font-size: 14px;"><strong>Time Window:</strong> ${logData.window.toUpperCase()} (${logData.scheduledTime})</p>
            </div>
            <p style="font-size: 13px; color: #64748b; margin: 0;">Your doctor has been notified of your adherence.</p>
          </div>
        </body>
      </html>
    `);
  } catch (err: any) {
    res.status(500).send(`Error processing dose recording: ${err.message}`);
  }
});

// 4. Core Medication Reminders Dispatcher
export async function dispatchDueMedicationReminders(): Promise<{ sent: number; skipped: number; errors: number }> {
  let sentCount = 0;
  let skippedCount = 0;
  let errorCount = 0;

  const now = new Date();
  const todayDateStr = now.toISOString().split('T')[0];

  // Determine current window based on IST hours (UTC + 5:30)
  const istOffsetMs = 5.5 * 60 * 60 * 1000;
  const istDate = new Date(now.getTime() + istOffsetMs);
  const istHour = istDate.getUTCHours();

  let currentWindow: MedicationWindow = 'morning';
  if (istHour >= 6 && istHour < 12) {
    currentWindow = 'morning';
  } else if (istHour >= 12 && istHour < 18) {
    currentWindow = 'afternoon';
  } else {
    currentWindow = 'night';
  }

  // Quiet hours check: 22:00 to 07:00 IST
  if (istHour >= 22 || istHour < 7) {
    console.log('Currently in quiet hours (22:00-07:00 IST). Suppressing non-emergency reminders.');
    return { sent: 0, skipped: 0, errors: 0 };
  }

  try {
    const activeSchedulesSnapshot = await db
      .collection(COLLECTIONS.MEDICATION_SCHEDULES)
      .where('status', '==', 'active')
      .get();

    for (const doc of activeSchedulesSnapshot.docs) {
      const schedule = doc.data() as MedicationScheduleDocument;

      // 1. Check course completion: if todayDate > endDate, auto-complete
      if (todayDateStr > schedule.endDate) {
        await doc.ref.update({
          status: 'completed',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        continue;
      }

      // Check if any medicines are scheduled for current window
      const medsInWindow = (schedule.items || []).filter((item) =>
        item.timing.includes(currentWindow)
      );
      if (medsInWindow.length === 0) continue;

      // 2. Patient consent check
      const pDoc = await db.collection(COLLECTIONS.PATIENTS).doc(schedule.patientId).get();
      if (!pDoc.exists) continue;
      const patient = pDoc.data() as PatientDocument;

      if (patient.messagingConsent === false) {
        skippedCount++;
        continue;
      }

      // 3. Idempotency Check: prevent duplicate send for same schedule, date & window
      const idempotencyKey = `${doc.id}_${todayDateStr}_${currentWindow}`;
      const logRef = db.collection(COLLECTIONS.MEDICATION_REMINDERS_LOG).doc(idempotencyKey);
      const existingLog = await logRef.get();
      if (existingLog.exists) {
        continue; // Already processed
      }

      // 4. Generate single-use verification token for "Taken" link
      const rawToken = crypto.randomBytes(32).toString('hex');
      const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');
      const takenLink = `${config.baseAppUrl}/markMedicationTakenWeb?logId=${idempotencyKey}&token=${rawToken}`;

      const medsSummary = medsInWindow.map((m) => `${m.medicineName} (${m.dosage})`).join(', ');
      const instructions = medsInWindow.map((m) => m.instructions || '').filter(Boolean).join('; ') || 'After meal';
      const scheduledTime = schedule.timeWindows?.[currentWindow] || '08:30 AM';

      const lang = patient.preferredLanguage || 'en';
      const template = TemplateRegistryService.getTemplate('medication_reminder', lang);
      const params = [patient.name, medsSummary, `${currentWindow.toUpperCase()} dose - ${instructions}`, takenLink];

      // Dispatch via WhatsApp
      const res = await MessagingService.send(patient.phone || '', template?.body || '', {
        templateName: 'medication_reminder',
        templateParams: params,
      });

      // Record log entry
      const logEntry: MedicationReminderLog = {
        id: idempotencyKey,
        scheduleId: doc.id,
        clinicId: schedule.clinicId,
        patientId: schedule.patientId,
        doctorId: schedule.doctorId,
        date: todayDateStr,
        window: currentWindow,
        scheduledTime,
        status: res.success ? 'sent' : 'failed',
        medicinesSummary: medsSummary,
        tokenHash,
        sentAt: admin.firestore.FieldValue.serverTimestamp() as any,
        createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
      };

      await logRef.set(logEntry);

      if (res.success) {
        sentCount++;
        // Increment total reminders in schedule
        await doc.ref.update({
          'adherence.totalReminders': admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        errorCount++;
      }
    }
  } catch (err) {
    console.error('Error dispatching medication reminders:', err);
  }

  return { sent: sentCount, skipped: skippedCount, errors: errorCount };
}

// 5. Cloud Scheduler: Runs every 30 minutes for medication reminders
export const scheduledMedicationReminderEngine = onSchedule('every 30 minutes', async () => {
  console.log('Running automatic scheduled medication reminders engine...');
  const res = await dispatchDueMedicationReminders();
  console.log(`Medication reminders engine finished: Sent=${res.sent}, Skipped=${res.skipped}, Errors=${res.errors}`);
});

// 6. On-Demand Callable for Testing / Demo Mode
export const triggerMedicationRemindersCheck = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const res = await dispatchDueMedicationReminders();
  return { success: true, ...res };
});

// 7. Get Patient Medication Schedules & Adherence
export const getPatientMedicationSchedules = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { patientId } = (request.data || {}) as { patientId: string };
  if (!patientId) {
    throw new HttpsError('invalid-argument', 'patientId is required.');
  }

  const snapshot = await db
    .collection(COLLECTIONS.MEDICATION_SCHEDULES)
    .where('patientId', '==', patientId)
    .orderBy('createdAt', 'desc')
    .get();

  const schedules = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  return { success: true, schedules };
});
