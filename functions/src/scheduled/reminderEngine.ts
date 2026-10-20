import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { db, COLLECTIONS } from '../config/index.js';
import { FollowUpService } from '../services/followUpService.js';
import { NotificationService } from '../services/notificationService.js';
import { EmailService } from '../services/emailService.js';
import { AppointmentDocument, PatientDocument, UserDocument } from '../types/index.js';

/**
 * Core Reminder Processor
 * Evaluates upcoming appointments, checks deduplication, and sends reminders
 */
export async function processAppointmentReminders(options: {
  isDemoMode?: boolean;
  demoOffsetMinutes?: number;
}): Promise<{ processed: number; sent: number; errors: number }> {
  const now = new Date();
  let processedCount = 0;
  let sentCount = 0;
  let errorCount = 0;

  // Define time window
  const windowStart = new Date(now.getTime());
  // In production, look ahead 25 hours. In demo mode, look ahead according to demoOffset
  const lookaheadMinutes = options.isDemoMode
    ? (options.demoOffsetMinutes || 10) + 2
    : 25 * 60;

  const windowEnd = new Date(now.getTime() + lookaheadMinutes * 60 * 1000);

  // Query appointments that are Scheduled or Confirmed and haven't had 24h reminder sent
  const snapshot = await db
    .collection(COLLECTIONS.APPOINTMENTS)
    .where('reminder24hSent', '==', false)
    .where('status', 'in', ['Scheduled', 'Confirmed'])
    .get();

  for (const doc of snapshot.docs) {
    processedCount++;
    const appt = doc.data() as AppointmentDocument;
    const apptId = doc.id;

    try {
      const apptDateTime = FollowUpService.parseAppointmentDateTime(appt.date, appt.time);
      const timeDiffMs = apptDateTime.getTime() - now.getTime();
      const timeDiffMinutes = Math.floor(timeDiffMs / (60 * 1000));

      let shouldSend = false;

      if (options.isDemoMode) {
        // In Demo Mode: trigger if appointment is within demoOffsetMinutes (e.g. within 5 mins or 10 mins)
        const targetOffset = options.demoOffsetMinutes || 5;
        if (timeDiffMinutes <= targetOffset && timeDiffMinutes >= -5) {
          shouldSend = true;
        }
      } else {
        // Production Mode: trigger if appointment is roughly 24 hours away (between 22h and 26h) or closer
        if (timeDiffMinutes <= 24 * 60 && timeDiffMinutes > 0) {
          shouldSend = true;
        }
      }

      if (!shouldSend) {
        continue;
      }

      // Fetch Patient & Doctor details
      const patientDoc = await db.collection(COLLECTIONS.PATIENTS).doc(appt.patientId).get();
      if (!patientDoc.exists) continue;
      const patient = patientDoc.data() as PatientDocument;

      const doctorDoc = await db.collection(COLLECTIONS.USERS).doc(appt.doctorId).get();
      const doctor = doctorDoc.data() as UserDocument;
      const doctorName = doctor?.name || 'Doctor';

      const notificationType = options.isDemoMode
        ? 'appointment_reminder_demo'
        : 'appointment_reminder_24h';

      // 1. Dispatch Patient Reminder Email & SMS
      const dispatches = [];

      if (patient.email && patient.email.includes('@')) {
        dispatches.push(
          NotificationService.dispatch({
            doctorId: appt.doctorId,
            patientId: appt.patientId,
            appointmentId: apptId,
            type: notificationType,
            messagingConsent: patient.messagingConsent,
            email: {
              to: patient.email,
              subject: `Reminder: Appointment tomorrow with Dr. ${doctorName}`,
              html: EmailService.getAppointmentReminderTemplate({
                patientName: patient.name,
                doctorName: doctorName,
                appointmentDate: appt.date,
                appointmentTime: appt.time,
                appointmentType: appt.type,
              }),
            },
          })
        );
      }

      if (patient.phone && patient.phone.trim().length > 5) {
        dispatches.push(
          NotificationService.dispatch({
            doctorId: appt.doctorId,
            patientId: appt.patientId,
            appointmentId: apptId,
            type: notificationType,
            messagingConsent: patient.messagingConsent,
            messaging: {
              to: patient.phone,
              message: `Reminder: Your appointment with Dr. ${doctorName} is tomorrow at ${appt.time}.`,
              opts: {
                templateName: 'appointment_reminder',
                templateParams: [doctorName, appt.date, appt.time],
                telegramChatId: patient.telegramChatId,
              },
            },
          })
        );
      }

      // 2. Dispatch Doctor Push Reminder
      if (doctor?.fcmToken) {
        dispatches.push(
          NotificationService.dispatch({
            doctorId: appt.doctorId,
            patientId: appt.patientId,
            appointmentId: apptId,
            type: 'doctor_appointment_reminder',
            push: {
              token: doctor.fcmToken,
              title: 'Upcoming Appointment Reminder',
              body: `Appointment tomorrow: ${patient.name} — ${appt.time}`,
              data: { appointmentId: apptId, patientId: appt.patientId },
              isDoctorAlert: true,
            },
          })
        );
      }

      await Promise.all(dispatches);

      // 3. Mark as sent atomically to guarantee idempotence (never sent twice)
      await doc.ref.update({
        reminder24hSent: true,
        lastReminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      sentCount++;
    } catch (itemErr) {
      console.error(`Error processing reminder for appointment ${apptId}:`, itemErr);
      errorCount++;
    }
  }

  return { processed: processedCount, sent: sentCount, errors: errorCount };
}

/**
 * Cloud Scheduler 2nd Gen scheduled job (Runs every 15 minutes)
 */
export const scheduledReminderEngine = onSchedule('every 15 minutes', async (event) => {
  console.log('Running automatic 24-hour scheduled reminder engine...');
  const result = await processAppointmentReminders({ isDemoMode: false });
  console.log(`Reminder engine execution finished: Processed=${result.processed}, Sent=${result.sent}, Errors=${result.errors}`);
});

/**
 * On-demand Callable for testing & Demonstration Mode
 */
export const triggerDemoReminderCheck = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { offsetMinutes = 5 } = (request.data || {}) as { offsetMinutes?: number };

  const result = await processAppointmentReminders({
    isDemoMode: true,
    demoOffsetMinutes: offsetMinutes,
  });

  return {
    success: true,
    message: `Demo reminder check triggered with ${offsetMinutes}m offset.`,
    ...result,
  };
});
