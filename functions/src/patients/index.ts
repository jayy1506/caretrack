import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { db, COLLECTIONS } from '../config/index.js';
import { NotificationService } from '../services/notificationService.js';
import { EmailService } from '../services/emailService.js';
import { PatientDocument, UserDocument } from '../types/index.js';

export const sendPatientRegistrationNotification = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Doctor must be authenticated.');
  }

  const { patientId } = request.data as { patientId: string };
  if (!patientId) {
    throw new HttpsError('invalid-argument', 'Patient ID is required.');
  }

  const doctorUid = request.auth.uid;

  // Retrieve patient
  const patientDoc = await db.collection(COLLECTIONS.PATIENTS).doc(patientId).get();
  if (!patientDoc.exists) {
    throw new HttpsError('not-found', 'Patient record not found.');
  }

  const patient = patientDoc.data() as PatientDocument;
  if (patient.doctorId !== doctorUid) {
    throw new HttpsError('permission-denied', 'You do not have access to this patient record.');
  }

  // Retrieve doctor profile
  const doctorDoc = await db.collection(COLLECTIONS.USERS).doc(doctorUid).get();
  const doctor = doctorDoc.data() as UserDocument;
  const doctorName = doctor?.name || 'Doctor';

  // Dispatch notifications
  const dispatchPromises = [];

  // 1. Patient Email
  if (patient.email && patient.email.includes('@')) {
    dispatchPromises.push(
      NotificationService.dispatch({
        doctorId: doctorUid,
        patientId: patientId,
        type: 'patient_registration',
        messagingConsent: patient.messagingConsent,
        email: {
          to: patient.email,
          subject: 'Welcome to CareTrack Clinic Services',
          html: EmailService.getPatientRegistrationTemplate(patient.name, doctorName, doctor?.phone),
        },
      })
    );
  }

  // 2. Patient Messaging
  if (patient.phone && patient.phone.trim().length > 5) {
    dispatchPromises.push(
      NotificationService.dispatch({
        doctorId: doctorUid,
        patientId: patientId,
        type: 'patient_registration',
        messagingConsent: patient.messagingConsent,
        messaging: {
          to: patient.phone,
          message: `Hello ${patient.name}, you have been successfully registered with Dr. ${doctorName}. CareTrack will send your appointment and follow-up reminders here.`,
          opts: {
            templateName: 'welcome',
            templateParams: [patient.name, doctorName],
            telegramChatId: patient.telegramChatId,
          },
        },
      })
    );
  }

  // 3. Doctor Push confirmation (if doctor has registered FCM token)
  if (doctor?.fcmToken) {
    dispatchPromises.push(
      NotificationService.dispatch({
        doctorId: doctorUid,
        patientId: patientId,
        type: 'patient_registration',
        push: {
          token: doctor.fcmToken,
          title: 'Patient Registered',
          body: `Patient ${patient.name} has been successfully registered.`,
          data: { patientId },
          isDoctorAlert: true,
        },
      })
    );
  }

  const results = await Promise.all(dispatchPromises);

  return {
    success: true,
    message: 'Patient registration notifications dispatched.',
    dispatches: results.flat(),
  };
});
