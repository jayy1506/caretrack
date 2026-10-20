import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { db, config, COLLECTIONS } from '../config/index.js';
import { NotificationService } from '../services/notificationService.js';
import { EmailService } from '../services/emailService.js';
import { AppointmentDocument, PatientDocument, UserDocument } from '../types/index.js';

/**
 * Public HTTPS endpoint allowing patients to confirm or request reschedule with 1-click
 */
export const confirmAppointmentWeb = onRequest({ cors: true }, async (req, res) => {
  const { id, action } = req.query as { id?: string; action?: string };

  if (!id || !action) {
    res.status(400).send(`
      <html>
        <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
          <h2 style="color: #dc2626;">Invalid Request</h2>
          <p>Appointment ID or action parameter missing.</p>
        </body>
      </html>
    `);
    return;
  }

  try {
    const apptRef = db.collection(COLLECTIONS.APPOINTMENTS).doc(id);
    const apptDoc = await apptRef.get();

    if (!apptDoc.exists) {
      res.status(404).send(`
        <html>
          <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
            <h2 style="color: #dc2626;">Appointment Not Found</h2>
            <p>The appointment record does not exist or has already been updated.</p>
          </body>
        </html>
      `);
      return;
    }

    const apptData = apptDoc.data() as AppointmentDocument;

    if (action === 'confirm') {
      await apptRef.update({
        confirmationStatus: 'Confirmed',
        status: 'Confirmed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(200).send(`
        <html>
          <head><title>Appointment Confirmed - CareTrack</title></head>
          <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px; background-color: #f8fafc; color: #1e293b;">
            <div style="max-width: 500px; margin: 0 auto; background: #ffffff; padding: 30px; border-radius: 8px; border: 1px solid #e2e8f0; box-shadow: 0 2px 4px rgba(0,0,0,0.05);">
              <div style="width: 50px; height: 50px; border-radius: 25px; background: #dcfce7; color: #16a34a; line-height: 50px; font-size: 24px; margin: 0 auto 16px;">✓</div>
              <h2 style="color: #16a34a; margin: 0 0 10px;">Appointment Confirmed</h2>
              <p>Thank you! Your appointment on <strong>${apptData.date}</strong> at <strong>${apptData.time}</strong> is confirmed.</p>
              <p style="font-size: 13px; color: #64748b;">The doctor's clinic has been updated.</p>
            </div>
          </body>
        </html>
      `);
      return;
    } else if (action === 'reschedule') {
      await apptRef.update({
        confirmationStatus: 'Reschedule Requested',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(200).send(`
        <html>
          <head><title>Reschedule Requested - CareTrack</title></head>
          <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px; background-color: #f8fafc; color: #1e293b;">
            <div style="max-width: 500px; margin: 0 auto; background: #ffffff; padding: 30px; border-radius: 8px; border: 1px solid #e2e8f0; box-shadow: 0 2px 4px rgba(0,0,0,0.05);">
              <div style="width: 50px; height: 50px; border-radius: 25px; background: #fef3c7; color: #d97706; line-height: 50px; font-size: 24px; margin: 0 auto 16px;">⏳</div>
              <h2 style="color: #d97706; margin: 0 0 10px;">Reschedule Requested</h2>
              <p>We have notified the clinic that you wish to reschedule your appointment on <strong>${apptData.date}</strong>.</p>
              <p style="font-size: 13px; color: #64748b;">The clinic will get in touch with you shortly to coordinate a new time.</p>
            </div>
          </body>
        </html>
      `);
      return;
    } else {
      res.status(400).send('Invalid action specified.');
    }
  } catch (err: any) {
    res.status(500).send(`Internal error updating appointment status: ${err.message}`);
  }
});

/**
 * Callable function to send appointment confirmation messages to patient
 */
export const sendAppointmentConfirmation = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Doctor must be authenticated.');
  }

  const { appointmentId } = request.data as { appointmentId: string };
  if (!appointmentId) {
    throw new HttpsError('invalid-argument', 'Appointment ID is required.');
  }

  const doctorUid = request.auth.uid;

  const apptDoc = await db.collection(COLLECTIONS.APPOINTMENTS).doc(appointmentId).get();
  if (!apptDoc.exists) {
    throw new HttpsError('not-found', 'Appointment not found.');
  }
  const appt = apptDoc.data() as AppointmentDocument;

  if (appt.doctorId !== doctorUid) {
    throw new HttpsError('permission-denied', 'You do not own this appointment record.');
  }

  const patientDoc = await db.collection(COLLECTIONS.PATIENTS).doc(appt.patientId).get();
  const patient = patientDoc.data() as PatientDocument;

  const doctorDoc = await db.collection(COLLECTIONS.USERS).doc(doctorUid).get();
  const doctor = doctorDoc.data() as UserDocument;
  const doctorName = doctor?.name || 'Doctor';

  const confirmUrl = `${config.baseAppUrl}/confirmAppointmentWeb?id=${appointmentId}&action=confirm`;
  const rescheduleUrl = `${config.baseAppUrl}/confirmAppointmentWeb?id=${appointmentId}&action=reschedule`;

  const dispatchPromises = [];

  // 1. Email with confirm/reschedule action buttons
  if (patient?.email && patient.email.includes('@')) {
    dispatchPromises.push(
      NotificationService.dispatch({
        doctorId: doctorUid,
        patientId: appt.patientId,
        appointmentId: appointmentId,
        type: 'appointment_confirmation',
        messagingConsent: patient?.messagingConsent,
        email: {
          to: patient.email,
          subject: `Appointment with Dr. ${doctorName} on ${appt.date}`,
          html: EmailService.getAppointmentConfirmationTemplate({
            patientName: patient.name,
            doctorName: doctorName,
            appointmentDate: appt.date,
            appointmentTime: appt.time,
            appointmentType: appt.type,
            confirmUrl,
            rescheduleUrl,
          }),
        },
      })
    );
  }

  // 2. Messaging with confirmation instructions
  if (patient?.phone && patient.phone.trim().length > 5) {
    dispatchPromises.push(
      NotificationService.dispatch({
        doctorId: doctorUid,
        patientId: appt.patientId,
        appointmentId: appointmentId,
        type: 'appointment_confirmation',
        messagingConsent: patient?.messagingConsent,
        messaging: {
          to: patient.phone,
          message: `Your appointment with Dr. ${doctorName} is scheduled for ${appt.date} at ${appt.time}. Confirm here: ${confirmUrl}`,
          opts: {
            templateName: 'appointment_confirmation',
            templateParams: [doctorName, appt.date, appt.time, confirmUrl],
            telegramChatId: patient?.telegramChatId,
          },
        },
      })
    );
  }

  const results = await Promise.all(dispatchPromises);

  return {
    success: true,
    message: 'Appointment confirmation notifications sent.',
    dispatches: results.flat(),
  };
});
