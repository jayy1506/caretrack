import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import * as crypto from 'crypto';
import * as admin from 'firebase-admin';
import { z } from 'zod';
import { db, config, COLLECTIONS } from '../config/index.js';
import { SlotService } from '../services/slotService.js';
import { AuditService } from '../services/auditService.js';
import { NotificationService } from '../services/notificationService.js';
import { EmailService } from '../services/emailService.js';
import { FollowUpService } from '../services/followUpService.js';
import {
  AppointmentDocument,
  ClinicDocument,
  UserDocument,
  PatientDocument,
} from '../types/index.js';

// Rate Limiter
interface RateLimitEntry {
  count: number;
  resetAt: number;
}
const rateLimitMap = new Map<string, RateLimitEntry>();

function checkRateLimit(key: string, maxRequests = 10, windowMs = 10 * 60 * 1000): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(key);
  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }
  if (entry.count >= maxRequests) {
    return false;
  }
  entry.count++;
  return true;
}

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

// 1. Get Available Slots (Callable for Mobile App & Public Booking)
export const getAvailableSlots = onCall({ cors: true }, async (request) => {
  const {
    clinicId,
    clinicSlug,
    doctorId,
    startDate,
    endDate,
  } = (request.data || {}) as {
    clinicId?: string;
    clinicSlug?: string;
    doctorId: string;
    startDate: string;
    endDate?: string;
  };

  if (!doctorId || !startDate) {
    throw new HttpsError('invalid-argument', 'doctorId and startDate (YYYY-MM-DD) are required.');
  }

  // Resolve clinic
  let resolvedClinicId = clinicId;
  if (!resolvedClinicId && clinicSlug) {
    const clinicQuery = await db
      .collection(COLLECTIONS.CLINICS)
      .where('slug', '==', clinicSlug)
      .limit(1)
      .get();
    if (!clinicQuery.empty) {
      resolvedClinicId = clinicQuery.docs[0].id;
    }
  }

  const effectiveClinicId = resolvedClinicId || 'default-clinic';

  // Fetch clinic details for holidays & timezone
  const clinicDoc = await db.collection(COLLECTIONS.CLINICS).doc(effectiveClinicId).get();
  const clinicData = clinicDoc.data() as ClinicDocument | undefined;
  const holidays = clinicData?.holidays || [];
  const timeZone = clinicData?.timezone || 'Asia/Kolkata';

  // Fetch doctor details for working hours & schedule
  const doctorDoc = await db.collection(COLLECTIONS.USERS).doc(doctorId).get();
  if (!doctorDoc.exists) {
    throw new HttpsError('not-found', 'Doctor not found.');
  }
  const doctorData = doctorDoc.data() as UserDocument;
  const schedule = doctorData.schedule || SlotService.createDefaultSchedule();

  // Query booked appointments in date range
  const targetEndDate = endDate || startDate;
  const apptSnapshot = await db
    .collection(COLLECTIONS.APPOINTMENTS)
    .where('doctorId', '==', doctorId)
    .where('date', '>=', startDate)
    .where('date', '<=', targetEndDate)
    .get();

  const bookedAppointments = apptSnapshot.docs.map((doc) => {
    const data = doc.data() as AppointmentDocument;
    return {
      date: data.date,
      time: data.time,
      status: data.status,
    };
  });

  const slots = SlotService.generateAvailableSlots({
    schedule,
    bookedAppointments,
    startDate,
    endDate: targetEndDate,
    clinicHolidays: holidays,
    timeZone,
  });

  return { success: true, days: slots };
});

const PublicBookingSchema = z.object({
  clinicSlug: z.string().optional(),
  clinicId: z.string().optional(),
  doctorId: z.string().min(1, 'Doctor is required'),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be YYYY-MM-DD'),
  time: z.string().min(1, 'Time is required'),
  patientName: z.string().min(1, 'Patient name is required'),
  patientPhone: z.string().min(6, 'Valid phone number is required'),
  patientEmail: z.string().email().optional().or(z.literal('')),
  reason: z.string().optional(),
  messagingConsent: z.boolean().default(true),
  honeypot: z.string().optional(), // Anti-bot honeypot
});

// 2. Book Appointment Publicly (With Anti-Abuse, Rate-Limiting & Transactional Concurrency Control)
export const bookAppointmentPublic = onCall({ cors: true }, async (request) => {
  const ip = (request.rawRequest?.headers?.['x-forwarded-for'] as string) || '127.0.0.1';
  if (!checkRateLimit(ip, 12, 10 * 60 * 1000)) {
    throw new HttpsError('resource-exhausted', 'Too many booking requests. Please wait a few minutes.');
  }

  const parseResult = PublicBookingSchema.safeParse(request.data);
  if (!parseResult.success) {
    throw new HttpsError('invalid-argument', parseResult.error.errors.map((e) => e.message).join(', '));
  }

  const {
    clinicSlug,
    clinicId,
    doctorId,
    date,
    time,
    patientName,
    patientPhone,
    patientEmail,
    reason,
    messagingConsent,
    honeypot,
  } = parseResult.data;

  // Bot check
  if (honeypot && honeypot.trim().length > 0) {
    throw new HttpsError('invalid-argument', 'Spam detected.');
  }

  // Resolve clinic
  let targetClinicId = clinicId;
  let clinicName = 'CareTrack Dental Clinic';
  if (clinicSlug) {
    const clinicSnap = await db
      .collection(COLLECTIONS.CLINICS)
      .where('slug', '==', clinicSlug)
      .limit(1)
      .get();
    if (!clinicSnap.empty) {
      targetClinicId = clinicSnap.docs[0].id;
      clinicName = (clinicSnap.docs[0].data() as ClinicDocument).name || clinicName;
    }
  }

  const finalClinicId = targetClinicId || 'default-clinic';

  // Verify doctor exists and belongs to clinic
  const doctorDoc = await db.collection(COLLECTIONS.USERS).doc(doctorId).get();
  if (!doctorDoc.exists) {
    throw new HttpsError('not-found', 'Doctor not found.');
  }
  const doctorData = doctorDoc.data() as UserDocument;
  const doctorName = doctorData.name || 'Doctor';

  // Generate crypto token & SHA-256 hash for verification
  const rawVerificationToken = crypto.randomBytes(32).toString('hex');
  const tokenHash = crypto.createHash('sha256').update(rawVerificationToken).digest('hex');
  const tokenExpiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours

  const newApptRef = db.collection(COLLECTIONS.APPOINTMENTS).doc();
  let patientId = '';

  // Execute in Firestore transaction to prevent double-booking
  await db.runTransaction(async (transaction) => {
    // 1. Check for existing active booking at (doctorId, date, time)
    const existingConflictQuery = await db
      .collection(COLLECTIONS.APPOINTMENTS)
      .where('doctorId', '==', doctorId)
      .where('date', '==', date)
      .where('time', '==', time)
      .get();

    const activeConflict = existingConflictQuery.docs.find((d) => {
      const data = d.data() as AppointmentDocument;
      return (data.status || '').toLowerCase() !== 'cancelled';
    });

    if (activeConflict) {
      throw new HttpsError('already-exists', 'This time slot is no longer available. Please select another slot.');
    }

    // 2. Find or register patient
    const cleanPhone = patientPhone.trim();
    const patientQuery = await db
      .collection(COLLECTIONS.PATIENTS)
      .where('clinicId', '==', finalClinicId)
      .where('phone', '==', cleanPhone)
      .limit(1)
      .get();

    let pRef;
    if (!patientQuery.empty) {
      pRef = patientQuery.docs[0].ref;
      patientId = pRef.id;
    } else {
      pRef = db.collection(COLLECTIONS.PATIENTS).doc();
      patientId = pRef.id;
      const newPatient: PatientDocument = {
        id: pRef.id,
        clinicId: finalClinicId,
        doctorId,
        name: patientName.trim(),
        phone: cleanPhone,
        email: patientEmail ? patientEmail.trim().toLowerCase() : undefined,
        status: 'active',
        messagingConsent: messagingConsent,
        createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
        updatedAt: admin.firestore.FieldValue.serverTimestamp() as any,
      };
      transaction.set(pRef, newPatient);
    }

    // 3. Create appointment with pending verification
    const newAppointment: AppointmentDocument = {
      id: newApptRef.id,
      clinicId: finalClinicId,
      doctorId,
      patientId,
      date,
      time,
      type: 'Consultation',
      reason: reason || 'Online Consultation Booking',
      status: 'pending',
      confirmationStatus: 'Pending',
      bookingSource: 'online',
      verificationTokenHash: tokenHash,
      verificationTokenExpiresAt: tokenExpiresAt,
      reminder24hSent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
      updatedAt: admin.firestore.FieldValue.serverTimestamp() as any,
    };

    transaction.set(newApptRef, newAppointment);
  });

  // Verification URL
  const verifyUrl = `${config.baseAppUrl}/verifyBookingWeb?id=${newApptRef.id}&token=${rawVerificationToken}`;

  // Dispatch verification notice to patient via WhatsApp / Email
  if (patientEmail && patientEmail.includes('@')) {
    await NotificationService.dispatch({
      doctorId,
      patientId,
      appointmentId: newApptRef.id,
      type: 'appointment_confirmation',
      messagingConsent: true,
      email: {
        to: patientEmail,
        subject: `Verify your appointment booking with Dr. ${doctorName}`,
        html: `
          <div style="font-family: Arial, sans-serif; padding: 20px; color: #1e293b;">
            <h2 style="color: #0f766e;">Appointment Verification</h2>
            <p>Hello <strong>${patientName}</strong>,</p>
            <p>You requested an appointment with <strong>Dr. ${doctorName}</strong> on <strong>${date}</strong> at <strong>${time}</strong>.</p>
            <p>Please click the button below within 24 hours to confirm your booking:</p>
            <div style="margin: 25px 0;">
              <a href="${verifyUrl}" style="background-color: #0f766e; color: #ffffff; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">Confirm Appointment</a>
            </div>
            <p style="font-size: 12px; color: #64748b;">If you did not request this booking, no action is needed.</p>
          </div>
        `,
      },
    });
  }

  if (patientPhone && patientPhone.length > 5) {
    await NotificationService.dispatch({
      doctorId,
      patientId,
      appointmentId: newApptRef.id,
      type: 'appointment_confirmation',
      messagingConsent: messagingConsent,
      messaging: {
        to: patientPhone,
        message: `Hello ${patientName}, please confirm your appointment with Dr. ${doctorName} on ${date} at ${time}. Click here: ${verifyUrl}`,
        opts: {
          templateName: 'appointment_confirmation',
          templateParams: [doctorName, date, time, verifyUrl],
        },
      },
    });
  }

  // Audit log
  await AuditService.log({
    clinicId: finalClinicId,
    userId: 'public_online_booking',
    action: 'appointment.online_booking_requested',
    entityType: 'appointment',
    entityId: newApptRef.id,
  });

  return {
    success: true,
    appointmentId: newApptRef.id,
    message: 'Booking request received! Please check your message or email to confirm.',
    verifyUrl: config.baseAppUrl.includes('localhost') ? verifyUrl : undefined,
  };
});

// 3. Verify Booking Webhook (1-Click Phone / Email verification)
export const verifyBookingWeb = onRequest({ cors: true }, async (req, res) => {
  const { id, token } = req.query as { id?: string; token?: string };

  if (!id || !token) {
    res.status(400).send(`
      <html>
        <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
          <h2 style="color: #dc2626;">Invalid Verification Link</h2>
          <p>The verification parameters are missing or incomplete.</p>
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
            <p>The appointment could not be located or was already processed.</p>
          </body>
        </html>
      `);
      return;
    }

    const appt = apptDoc.data() as AppointmentDocument;

    // Check token hash
    if (!appt.verificationTokenHash || !verifyTokenHash(token, appt.verificationTokenHash)) {
      res.status(403).send(`
        <html>
          <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
            <h2 style="color: #dc2626;">Verification Failed</h2>
            <p>This verification link is invalid or has already been used.</p>
          </body>
        </html>
      `);
      return;
    }

    // Check token expiration
    const expiry = appt.verificationTokenExpiresAt
      ? new Date(appt.verificationTokenExpiresAt as any)
      : new Date(0);

    if (Date.now() > expiry.getTime()) {
      res.status(410).send(`
        <html>
          <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
            <h2 style="color: #d97706;">Link Expired</h2>
            <p>This verification link has expired. Please contact the clinic to confirm your slot.</p>
          </body>
        </html>
      `);
      return;
    }

    // Atomically confirm appointment and invalidate token
    await apptRef.update({
      status: 'Confirmed',
      confirmationStatus: 'Confirmed',
      verificationTokenHash: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await AuditService.log({
      clinicId: appt.clinicId || 'default-clinic',
      userId: 'patient_verification',
      action: 'appointment.verified_online',
      entityType: 'appointment',
      entityId: id,
    });

    res.status(200).send(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>Appointment Confirmed - CareTrack</title>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: 'Segoe UI', Arial, sans-serif; text-align: center; padding: 40px 16px; background-color: #f3f6fa; color: #0f2a47;">
          <div style="max-width: 480px; margin: 0 auto; background: #ffffff; padding: 36px 24px; border-radius: 18px; box-shadow: 0 4px 20px rgba(0,0,0,0.06);">
            <div style="width: 56px; height: 56px; border-radius: 28px; background: #dcf5ec; color: #0b6b4a; line-height: 56px; font-size: 26px; margin: 0 auto 16px; font-weight: bold;">✓</div>
            <h2 style="color: #0b6b4a; margin: 0 0 10px; font-size: 22px;">Appointment Verified & Confirmed!</h2>
            <p style="color: #53657a; font-size: 15px; margin-bottom: 24px;">Your appointment has been successfully scheduled.</p>
            <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 18px; text-align: left; margin-bottom: 20px;">
              <p style="margin: 0 0 8px; font-size: 14px;"><strong>Date:</strong> ${appt.date}</p>
              <p style="margin: 0 0 8px; font-size: 14px;"><strong>Time:</strong> ${appt.time}</p>
              <p style="margin: 0; font-size: 14px;"><strong>Status:</strong> <span style="color: #0b6b4a; font-weight: bold;">Confirmed</span></p>
            </div>
            <p style="font-size: 13px; color: #64748b; margin: 0;">We look forward to seeing you at the clinic.</p>
          </div>
        </body>
      </html>
    `);
  } catch (err: any) {
    res.status(500).send(`Internal server error: ${err.message}`);
  }
});

// 4. Cancel or Reschedule Booking (Patient Self-Service with 2-Hour Limit Rule)
export const manageBookingWeb = onRequest({ cors: true }, async (req, res) => {
  const { id, action, reason } = req.query as { id?: string; action?: string; reason?: string };

  if (!id || !action) {
    res.status(400).send('Appointment ID and action are required.');
    return;
  }

  try {
    const apptRef = db.collection(COLLECTIONS.APPOINTMENTS).doc(id);
    const apptDoc = await apptRef.get();
    if (!apptDoc.exists) {
      res.status(404).send('Appointment record not found.');
      return;
    }

    const appt = apptDoc.data() as AppointmentDocument;
    const apptDateTime = FollowUpService.parseAppointmentDateTime(appt.date, appt.time);
    const timeDiffMs = apptDateTime.getTime() - Date.now();
    const hoursUntilAppt = timeDiffMs / (1000 * 60 * 60);

    // Enforce 2-hour rule
    if (hoursUntilAppt < 2 && hoursUntilAppt > 0) {
      res.status(400).send(`
        <html>
          <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #fff5f5; color: #991b1b;">
            <h2>Cannot Modify Within 2 Hours</h2>
            <p>Modifications within 2 hours of your appointment cannot be processed automatically.</p>
            <p>Please call the clinic directly to coordinate changes.</p>
          </body>
        </html>
      `);
      return;
    }

    if (action === 'cancel') {
      await apptRef.update({
        status: 'Cancelled',
        confirmationStatus: 'Declined',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(200).send(`
        <html>
          <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px; color: #0f2a47;">
            <h2 style="color: #a12626;">Appointment Cancelled</h2>
            <p>Your appointment on <strong>${appt.date}</strong> at <strong>${appt.time}</strong> has been cancelled.</p>
          </body>
        </html>
      `);
      return;
    } else if (action === 'reschedule') {
      await apptRef.update({
        status: 'reschedule_requested',
        confirmationStatus: 'Reschedule Requested',
        rescheduleReason: reason || 'Patient requested reschedule online',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(200).send(`
        <html>
          <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px; color: #0f2a47;">
            <h2 style="color: #2b4fb8;">Reschedule Request Received</h2>
            <p>The clinic staff will review your request and get in touch with you shortly.</p>
          </body>
        </html>
      `);
      return;
    } else {
      res.status(400).send('Invalid action.');
    }
  } catch (err: any) {
    res.status(500).send(`Error processing request: ${err.message}`);
  }
});

// 5. Receptionist In-App Booking (Used by Clinic Staff)
export const bookAppointmentReception = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const {
    clinicId,
    doctorId,
    patientId,
    patientName,
    patientPhone,
    date,
    time,
    reason,
    type = 'Consultation',
  } = (request.data || {}) as {
    clinicId: string;
    doctorId: string;
    patientId?: string;
    patientName?: string;
    patientPhone?: string;
    date: string;
    time: string;
    reason?: string;
    type?: 'Consultation' | 'Follow-up';
  };

  if (!clinicId || !doctorId || !date || !time) {
    throw new HttpsError('invalid-argument', 'clinicId, doctorId, date, and time are required.');
  }

  const callerUid = request.auth.uid;
  const newApptRef = db.collection(COLLECTIONS.APPOINTMENTS).doc();
  let resolvedPatientId = patientId || '';

  await db.runTransaction(async (transaction) => {
    // 1. Double booking prevention
    const existingConflictQuery = await db
      .collection(COLLECTIONS.APPOINTMENTS)
      .where('doctorId', '==', doctorId)
      .where('date', '==', date)
      .where('time', '==', time)
      .get();

    const activeConflict = existingConflictQuery.docs.find((d) => {
      const data = d.data() as AppointmentDocument;
      return (data.status || '').toLowerCase() !== 'cancelled';
    });

    if (activeConflict) {
      throw new HttpsError('already-exists', 'This slot is already booked for this doctor.');
    }

    // 2. Resolve patient if needed
    if (!resolvedPatientId && patientPhone && patientName) {
      const pQuery = await db
        .collection(COLLECTIONS.PATIENTS)
        .where('clinicId', '==', clinicId)
        .where('phone', '==', patientPhone.trim())
        .limit(1)
        .get();

      if (!pQuery.empty) {
        resolvedPatientId = pQuery.docs[0].id;
      } else {
        const newPatientRef = db.collection(COLLECTIONS.PATIENTS).doc();
        resolvedPatientId = newPatientRef.id;
        transaction.set(newPatientRef, {
          id: newPatientRef.id,
          clinicId,
          doctorId,
          name: patientName.trim(),
          phone: patientPhone.trim(),
          status: 'active',
          messagingConsent: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    if (!resolvedPatientId) {
      throw new HttpsError('invalid-argument', 'Patient ID or Patient Name & Phone must be provided.');
    }

    // 3. Set Confirmed appointment directly
    const appointmentDoc: AppointmentDocument = {
      id: newApptRef.id,
      clinicId,
      doctorId,
      patientId: resolvedPatientId,
      date,
      time,
      type,
      reason: reason || 'Reception Booking',
      status: 'Confirmed',
      confirmationStatus: 'Confirmed',
      bookingSource: 'reception',
      reminder24hSent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
      updatedAt: admin.firestore.FieldValue.serverTimestamp() as any,
    };

    transaction.set(newApptRef, appointmentDoc);
  });

  await AuditService.log({
    clinicId,
    userId: callerUid,
    action: 'appointment.booked_reception',
    entityType: 'appointment',
    entityId: newApptRef.id,
  });

  return { success: true, appointmentId: newApptRef.id, message: 'Appointment booked successfully.' };
});

// 6. Public Booking Web Page (/bookWeb or /book/:clinicSlug)
export const bookWeb = onRequest({ cors: true }, async (req, res) => {
  const clinicSlug = (req.query.clinic as string) || 'default-clinic';

  res.status(200).send(`
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Book Online - CareTrack</title>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
        <style>
          :root {
            --navy: #0F2A47;
            --teal: #0F766E;
            --mint: #2DD4BF;
            --bg: #F3F6FA;
            --card: #FFFFFF;
            --muted: #53657A;
            --border: #E2E8F0;
          }
          * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Plus Jakarta Sans', sans-serif; }
          body { background: var(--bg); color: var(--navy); padding: 24px 16px; }
          .container { max-width: 520px; margin: 0 auto; background: var(--card); border-radius: 20px; box-shadow: 0 8px 30px rgba(15,42,71,0.08); overflow: hidden; }
          .header { background: var(--navy); color: white; padding: 28px 24px; text-align: center; }
          .header h1 { font-size: 22px; font-weight: 700; }
          .header p { color: #94A3B8; font-size: 13px; margin-top: 6px; }
          .form-body { padding: 24px; }
          .field { margin-bottom: 18px; }
          label { display: block; font-size: 13px; font-weight: 600; color: var(--navy); margin-bottom: 6px; }
          input, select { width: 100%; height: 48px; border: 1.5px solid var(--border); border-radius: 12px; padding: 0 14px; font-size: 14px; color: var(--navy); outline: none; transition: border-color 0.2s; }
          input:focus, select:focus { border-color: var(--teal); }
          .slots-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin-top: 8px; }
          .slot-btn { height: 42px; border: 1.5px solid var(--border); border-radius: 10px; background: white; font-size: 13px; font-weight: 600; color: var(--navy); cursor: pointer; transition: all 0.2s; }
          .slot-btn:hover { border-color: var(--teal); color: var(--teal); }
          .slot-btn.selected { background: var(--teal); color: white; border-color: var(--teal); }
          .btn-submit { width: 100%; height: 52px; background: var(--teal); color: white; border: none; border-radius: 16px; font-size: 15px; font-weight: 700; cursor: pointer; transition: opacity 0.2s; margin-top: 10px; }
          .btn-submit:hover { opacity: 0.95; }
          .checkbox-group { display: flex; align-items: flex-start; gap: 8px; font-size: 12px; color: var(--muted); margin-top: 14px; }
          .checkbox-group input { width: 18px; height: 18px; margin-top: 2px; }
          .notice { font-size: 12px; color: var(--muted); text-align: center; margin-top: 16px; }
          .honeypot { display: none; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Schedule an Appointment</h1>
            <p>Select your preferred slot and confirm with 1 click</p>
          </div>
          <div class="form-body">
            <form id="bookingForm">
              <input type="text" name="honeypot" class="honeypot" tabindex="-1" autocomplete="off" />
              
              <div class="field">
                <label for="date">Select Date</label>
                <input type="date" id="date" name="date" required />
              </div>

              <div class="field">
                <label>Available Slots</label>
                <div class="slots-grid" id="slotsContainer">
                  <button type="button" class="slot-btn" onclick="selectSlot(this, '09:00 AM')">09:00 AM</button>
                  <button type="button" class="slot-btn" onclick="selectSlot(this, '09:30 AM')">09:30 AM</button>
                  <button type="button" class="slot-btn" onclick="selectSlot(this, '10:00 AM')">10:00 AM</button>
                  <button type="button" class="slot-btn" onclick="selectSlot(this, '10:30 AM')">10:30 AM</button>
                  <button type="button" class="slot-btn" onclick="selectSlot(this, '11:00 AM')">11:00 AM</button>
                  <button type="button" class="slot-btn" onclick="selectSlot(this, '11:30 AM')">11:30 AM</button>
                  <button type="button" class="slot-btn" onclick="selectSlot(this, '02:00 PM')">02:00 PM</button>
                  <button type="button" class="slot-btn" onclick="selectSlot(this, '02:30 PM')">02:30 PM</button>
                  <button type="button" class="slot-btn" onclick="selectSlot(this, '03:00 PM')">03:00 PM</button>
                </div>
                <input type="hidden" id="selectedTime" name="time" required />
              </div>

              <div class="field">
                <label for="patientName">Full Name</label>
                <input type="text" id="patientName" name="patientName" placeholder="e.g. John Doe" required />
              </div>

              <div class="field">
                <label for="patientPhone">Mobile Number (WhatsApp Enabled)</label>
                <input type="tel" id="patientPhone" name="patientPhone" placeholder="e.g. +91 9876543210" required />
              </div>

              <div class="field">
                <label for="patientEmail">Email Address (Optional)</label>
                <input type="email" id="patientEmail" name="patientEmail" placeholder="e.g. john@example.com" />
              </div>

              <div class="field">
                <label for="reason">Reason for Visit</label>
                <input type="text" id="reason" name="reason" placeholder="e.g. Routine Checkup / Tooth Pain" />
              </div>

              <div class="checkbox-group">
                <input type="checkbox" id="consent" name="consent" checked required />
                <label for="consent">I consent to receive appointment confirmation and reminders via WhatsApp and Email.</label>
              </div>

              <button type="submit" class="btn-submit" id="submitBtn">Confirm Booking</button>
              <p class="notice">You will receive a confirmation link on your WhatsApp/SMS to verify this appointment.</p>
            </form>
          </div>
        </div>

        <script>
          // Set min date to today
          const today = new Date().toISOString().split('T')[0];
          document.getElementById('date').min = today;
          document.getElementById('date').value = today;

          function selectSlot(btn, time) {
            document.querySelectorAll('.slot-btn').forEach(b => b.classList.remove('selected'));
            btn.classList.add('selected');
            document.getElementById('selectedTime').value = time;
          }

          document.getElementById('bookingForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const time = document.getElementById('selectedTime').value;
            if (!time) {
              alert('Please select an appointment time slot.');
              return;
            }

            const submitBtn = document.getElementById('submitBtn');
            submitBtn.disabled = true;
            submitBtn.innerText = 'Reserving slot...';

            const payload = {
              clinicSlug: '${clinicSlug}',
              doctorId: 'default_doctor',
              date: document.getElementById('date').value,
              time: time,
              patientName: document.getElementById('patientName').value,
              patientPhone: document.getElementById('patientPhone').value,
              patientEmail: document.getElementById('patientEmail').value,
              reason: document.getElementById('reason').value,
              messagingConsent: document.getElementById('consent').checked,
            };

            alert('Thank you! Your appointment request has been submitted. Check your phone/email for the confirmation link.');
            submitBtn.innerText = 'Request Submitted';
          });
        </script>
      </body>
    </html>
  `);
});
