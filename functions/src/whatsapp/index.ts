import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import * as crypto from 'crypto';
import * as admin from 'firebase-admin';
import { z } from 'zod';
import { db, config, COLLECTIONS } from '../config/index.js';
import { MessagingService, normalizePhoneNumber } from '../services/messagingService.js';
import { NotificationService } from '../services/notificationService.js';
import { AuditService } from '../services/auditService.js';
import { TemplateRegistryService } from '../services/templateRegistry.js';
import { FaqAssistantService } from '../services/faqAssistantService.js';
import { SmartTimingService } from '../services/smartTimingService.js';
import {
  PatientDocument,
  AppointmentDocument,
  ConversationThread,
  ConversationMessage,
  RecallCampaignDocument,
} from '../types/index.js';

// Keywords for multilingual command handling
const CONFIRM_KEYWORDS = new Set([
  '1', 'confirm', 'yes', 'y', 'haan', 'ha', 'ok',
  'पुष्टि', 'हाँ', 'हा', 'स्वीकार',
  'होय', 'नक्की', 'मान्य',
]);

const RESCHEDULE_KEYWORDS = new Set([
  '2', 'reschedule', 'change', 'shift', 'later',
  'बदलें', 'पुनर्निर्धारण', 'आगे बढ़ाएं',
  'वेळ बदला', 'पुढे ढकला',
]);

const STOP_KEYWORDS = new Set([
  'stop', 'unsubscribe', 'cancel', 'halt',
  'रोकें', 'बंद करें',
  'थांबवा', 'बंद करा',
]);

const URGENT_SYMPTOM_REGEX = /(pain|hurt|ache|bleed|bleeding|blood|fever|swelling|pus|emergency|stitch|दर्द|खून|सूज|ताप|बुखार|टाके|वेदना|रक्त)/i;

// 1. WhatsApp Webhook (Handshake & Inbound Message Processing)
export const whatsappWebhook = onRequest({ cors: true }, async (req, res) => {
  // A. Webhook verification handshake (Meta Graph API)
  if (req.method === 'GET') {
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    if (mode === 'subscribe' && token === config.whatsappVerifyToken) {
      console.log('WhatsApp webhook verified successfully.');
      res.status(200).send(challenge);
      return;
    } else {
      res.status(403).send('Forbidden: Verify token mismatch.');
      return;
    }
  }

  // B. Inbound Event Processing (POST)
  if (req.method === 'POST') {
    // Verify Meta X-Hub-Signature-256 header if secret is configured
    const signature = req.headers['x-hub-signature-256'] as string;
    if (config.whatsappAppSecret && signature) {
      try {
        const rawBody = (req as any).rawBody || JSON.stringify(req.body);
        const expectedSig = 'sha256=' + crypto.createHmac('sha256', config.whatsappAppSecret).update(rawBody).digest('hex');
        if (signature !== expectedSig) {
          console.warn('WhatsApp webhook signature verification failed.');
          res.status(401).send('Invalid signature.');
          return;
        }
      } catch (sigErr) {
        console.error('Error verifying signature:', sigErr);
      }
    }

    const body = req.body;
    if (!body || !body.entry) {
      res.status(200).send('EVENT_RECEIVED');
      return;
    }

    try {
      for (const entry of body.entry) {
        for (const change of entry.changes || []) {
          const val = change.value;
          if (!val) continue;

          // 1. Handle incoming message
          if (val.messages && val.messages.length > 0) {
            for (const msg of val.messages) {
              await handleIncomingWhatsAppMessage(msg, val.metadata?.phone_number_id);
            }
          }

          // 2. Handle delivery status updates (sent, delivered, read, failed)
          if (val.statuses && val.statuses.length > 0) {
            for (const status of val.statuses) {
              await handleWhatsAppStatusUpdate(status);
            }
          }
        }
      }
    } catch (procErr) {
      console.error('Error processing WhatsApp webhook payload:', procErr);
    }

    res.status(200).send('EVENT_RECEIVED');
    return;
  }

  res.status(405).send('Method Not Allowed');
});

/**
 * Process a single incoming WhatsApp message
 */
async function handleIncomingWhatsAppMessage(msg: any, phoneNumberId?: string) {
  const fromRaw = msg.from; // e.g. "919876543210"
  const textBody = (msg.text?.body || '').trim();
  const messageId = msg.id;

  if (!fromRaw || !textBody) return;

  const phoneNorm = normalizePhoneNumber(fromRaw);
  const normalizedPhone = phoneNorm.normalized || `+${fromRaw}`;

  // Find patient by phone number
  const patientQuery = await db
    .collection(COLLECTIONS.PATIENTS)
    .where('phone', '==', normalizedPhone)
    .limit(1)
    .get();

  let patientId = '';
  let patientName = 'Patient';
  let clinicId = 'default-clinic';
  let doctorId = '';
  let preferredLanguage: 'en' | 'hi' | 'mr' = 'en';

  if (!patientQuery.empty) {
    const pDoc = patientQuery.docs[0];
    patientId = pDoc.id;
    const pData = pDoc.data() as PatientDocument;
    patientName = pData.name || patientName;
    clinicId = pData.clinicId || clinicId;
    doctorId = pData.doctorId || doctorId;
    preferredLanguage = pData.preferredLanguage || 'en';
  } else {
    // Create new patient record for unknown sender
    const newPRef = db.collection(COLLECTIONS.PATIENTS).doc();
    patientId = newPRef.id;
    await newPRef.set({
      id: newPRef.id,
      clinicId,
      name: `WhatsApp User (${normalizedPhone.slice(-4)})`,
      phone: normalizedPhone,
      status: 'active',
      messagingConsent: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // Check symptom urgency
  const isUrgent = URGENT_SYMPTOM_REGEX.test(textBody);
  const cleanLower = textBody.toLowerCase();

  // Save message into conversations/{patientId}/messages/{messageId}
  const msgDoc: ConversationMessage = {
    id: messageId,
    sender: 'patient',
    text: textBody,
    timestamp: admin.firestore.FieldValue.serverTimestamp() as any,
    status: 'delivered',
    channel: 'whatsapp',
    isUrgent,
  };

  const threadRef = db.collection(COLLECTIONS.CONVERSATIONS).doc(patientId);
  const msgRef = threadRef.collection('messages').doc(messageId);

  const batch = db.batch();
  batch.set(msgRef, msgDoc);

  // Update conversation thread
  batch.set(
    threadRef,
    {
      id: patientId,
      clinicId,
      patientId,
      patientName,
      patientPhone: normalizedPhone,
      lastMessageText: textBody,
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      lastUserInboundAt: admin.firestore.FieldValue.serverTimestamp(),
      unreadCount: admin.firestore.FieldValue.increment(1),
      isUrgent: isUrgent,
      status: 'open',
    },
    { merge: true }
  );
  await batch.commit();

  // Telemetry for Smart Reminder Timing
  if (patientId) {
    try {
      const responseHour = SmartTimingService.getIstHour(new Date());
      await db.collection(COLLECTIONS.PATIENTS).doc(patientId).update({
        pastResponseHours: admin.firestore.FieldValue.arrayUnion(responseHour),
      });
    } catch {
      // Non-critical background telemetry
    }
  }

  // ---------------- COMMAND DISPATCH ----------------
  // A. CONFIRM APPOINTMENT
  if (CONFIRM_KEYWORDS.has(cleanLower)) {
    const apptQuery = await db
      .collection(COLLECTIONS.APPOINTMENTS)
      .where('patientId', '==', patientId)
      .where('status', 'in', ['Scheduled', 'pending'])
      .orderBy('date', 'asc')
      .limit(1)
      .get();

    if (!apptQuery.empty) {
      const apptDoc = apptQuery.docs[0];
      const apptData = apptDoc.data() as AppointmentDocument;

      await apptDoc.ref.update({
        status: 'Confirmed',
        confirmationStatus: 'Confirmed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const reply =
        preferredLanguage === 'hi'
          ? `धन्यवाद ${patientName}! डॉ. के साथ आपकी अपॉइंटमेंट (${apptData.date} को ${apptData.time}) सफलतापूर्वक पुष्टि हो गई है।`
          : preferredLanguage === 'mr'
          ? `धन्यवाद ${patientName}! आपली अपॉइंटमेंट (${apptData.date} रोजी ${apptData.time}) पुष्टी झाली आहे.`
          : `Thank you ${patientName}! Your appointment on ${apptData.date} at ${apptData.time} is now confirmed.`;

      await sendReplyWhatsApp(normalizedPhone, reply, patientId, clinicId);
      return;
    }
  }

  // B. RESCHEDULE APPOINTMENT
  if (RESCHEDULE_KEYWORDS.has(cleanLower)) {
    const apptQuery = await db
      .collection(COLLECTIONS.APPOINTMENTS)
      .where('patientId', '==', patientId)
      .where('status', 'in', ['Scheduled', 'Confirmed', 'pending'])
      .orderBy('date', 'asc')
      .limit(1)
      .get();

    if (!apptQuery.empty) {
      const apptDoc = apptQuery.docs[0];
      await apptDoc.ref.update({
        status: 'reschedule_requested',
        confirmationStatus: 'Reschedule Requested',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const reply =
        preferredLanguage === 'hi'
          ? `हमने अपॉइंटमेंट बदलने का आपका अनुरोध दर्ज कर लिया है। हमारे क्लिनिक कर्मचारी जल्द ही नई तारीख तय करने के लिए आपसे संपर्क करेंगे।`
          : preferredLanguage === 'mr'
          ? `आम्ही वेळ बदलण्याची आपली विनंती नोंदवली आहे. आमचे कर्मचारी नवीन वेळ निश्चित करण्यासाठी लवकरच संपर्क करतील.`
          : `We received your reschedule request. Our clinic reception will get in touch with you shortly to coordinate a new time.`;

      await sendReplyWhatsApp(normalizedPhone, reply, patientId, clinicId);
      return;
    }
  }

  // C. STOP / REVOKE CONSENT
  if (STOP_KEYWORDS.has(cleanLower)) {
    await db.collection(COLLECTIONS.PATIENTS).doc(patientId).update({
      messagingConsent: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const reply =
      preferredLanguage === 'hi'
        ? `आपको CareTrack संदेशों से अनसब्सक्राइब कर दिया गया है। पुनः शुरू करने के लिए कभी भी START भेजें।`
        : preferredLanguage === 'mr'
        ? `आपली सदस्यता रद्द केली गेली आहे. पुन्हा सुरू करण्यासाठी START पाठवा.`
        : `You have unsubscribed from CareTrack WhatsApp notifications. Reply START at any time to opt back in.`;

    await sendReplyWhatsApp(normalizedPhone, reply, patientId, clinicId);
    return;
  }

  // D. URGENT SYMPTOMS ALERT (No AI Medical Advice)
  if (isUrgent) {
    // Notify doctor / staff with high-priority alert
    if (doctorId) {
      const doctorDoc = await db.collection(COLLECTIONS.USERS).doc(doctorId).get();
      const docFCM = doctorDoc.data()?.fcmToken;
      if (docFCM) {
        await NotificationService.dispatch({
          doctorId,
          patientId,
          type: 'doctor_appointment_reminder',
          push: {
            token: docFCM,
            title: '⚠️ Urgent Patient Symptom Alert',
            body: `${patientName} reported urgent symptoms via WhatsApp: "${textBody}"`,
            data: { patientId, isUrgent: 'true' },
            isDoctorAlert: true,
          },
        });
      }
    }

    const urgentAck =
      preferredLanguage === 'hi'
        ? `नमस्ते ${patientName}, हमने आपके लक्षणों के संबंध में क्लिनिकल टीम को सूचित कर दिया है। डॉक्टर या स्टाफ आपसे शीघ्र संपर्क करेंगे। आपात स्थिति में तुरंत नजदीकी अस्पताल जाएं।`
        : preferredLanguage === 'mr'
        ? `नमस्कार ${patientName}, आम्ही आपल्या लक्षणांची माहिती डॉक्टरांना दिली आहे. आमचे कर्मचारी लवकरच संपर्क साधतील. आणीबाणी असल्यास कृपया तात्काळ रुग्णालयात जा.`
        : `Hello ${patientName}, we received your message and alerted our clinical team. Our staff will contact you shortly. If this is a medical emergency, please visit the nearest hospital immediately.`;

    await sendReplyWhatsApp(normalizedPhone, urgentAck, patientId, clinicId);
    return;
  }

  // E. FAQ ASSISTANT (Feature-flagged, off by default)
  try {
    const clinicDoc = await db.collection(COLLECTIONS.CLINICS).doc(clinicId).get();
    const featureFlags = clinicDoc.data()?.featureFlags;

    if (featureFlags?.faqAssistant) {
      const faqResult = await FaqAssistantService.queryFaq({
        clinicId,
        patientId,
        query: textBody,
        preferredLanguage,
      });

      if (faqResult.isClinicalHandoff) {
        await threadRef.update({
          isUrgent: true,
          urgentReasons: ['faq_clinical_symptom'],
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      await sendReplyWhatsApp(normalizedPhone, faqResult.answer, patientId, clinicId);
      return;
    }
  } catch (faqErr) {
    console.error('Error invoking FAQ assistant:', faqErr);
  }

  // Fallback: General inquiry acknowledgement
  const defaultAck =
    preferredLanguage === 'hi'
      ? `नमस्ते ${patientName}, संदेश के लिए धन्यवाद। हमारी क्लिनिक टीम को आपका संदेश मिल गया है और हम जल्द ही उत्तर देंगे।`
      : preferredLanguage === 'mr'
      ? `नमस्कार ${patientName}, मेसेज केल्याबद्दल धन्यवाद. आमची क्लिनिक टीम लवकरच उत्तर देईल.`
      : `Hello ${patientName}, thank you for reaching out. Our clinic front desk has received your message and will reply shortly.`;

  await sendReplyWhatsApp(normalizedPhone, defaultAck, patientId, clinicId);
}

/**
 * Dispatch an outbound reply message via WhatsApp and save to conversation thread
 */
async function sendReplyWhatsApp(to: string, messageText: string, patientId: string, clinicId: string) {
  const sendRes = await MessagingService.send(to, messageText, {
    isWithin24hWindow: true,
  });

  const replyMsgId = sendRes.messageId || `out_${Date.now()}`;
  const outDoc: ConversationMessage = {
    id: replyMsgId,
    sender: 'clinic',
    text: messageText,
    timestamp: admin.firestore.FieldValue.serverTimestamp() as any,
    status: sendRes.success ? 'sent' : 'failed',
    channel: 'whatsapp',
  };

  await db
    .collection(COLLECTIONS.CONVERSATIONS)
    .doc(patientId)
    .collection('messages')
    .doc(replyMsgId)
    .set(outDoc);
}

/**
 * Handle delivery status callbacks from WhatsApp
 */
async function handleWhatsAppStatusUpdate(status: any) {
  const messageId = status.id;
  const statusStr = status.status; // 'sent', 'delivered', 'read', 'failed'
  // Status tracking logic updates message doc if found
  try {
    const query = await db
      .collectionGroup('messages')
      .where('id', '==', messageId)
      .limit(1)
      .get();
    if (!query.empty) {
      await query.docs[0].ref.update({
        status: statusStr,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  } catch (_) {}
}

// 2. Staff Inbox: List Conversations
export const getClinicConversations = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { clinicId, status, urgentOnly } = (request.data || {}) as {
    clinicId?: string;
    status?: 'open' | 'resolved';
    urgentOnly?: boolean;
  };

  const callerClinicId = request.auth.token.clinicId || 'default-clinic';
  const effectiveClinicId = clinicId || callerClinicId;

  let query = db.collection(COLLECTIONS.CONVERSATIONS).where('clinicId', '==', effectiveClinicId);

  if (status) {
    query = query.where('status', '==', status);
  }
  if (urgentOnly) {
    query = query.where('isUrgent', '==', true);
  }

  const snapshot = await query.orderBy('lastMessageAt', 'desc').limit(50).get();
  const threads = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

  return { success: true, threads };
});

// 3. Staff Inbox: Reply to Conversation
export const replyConversation = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { patientId, message, templateName, templateParams } = (request.data || {}) as {
    patientId: string;
    message?: string;
    templateName?: string;
    templateParams?: string[];
  };

  if (!patientId || (!message && !templateName)) {
    throw new HttpsError('invalid-argument', 'patientId and either message or templateName are required.');
  }

  const threadDoc = await db.collection(COLLECTIONS.CONVERSATIONS).doc(patientId).get();
  if (!threadDoc.exists) {
    throw new HttpsError('not-found', 'Conversation thread not found.');
  }

  const thread = threadDoc.data() as ConversationThread;

  // Determine if inside 24-hour window
  const lastInbound = thread.lastUserInboundAt
    ? new Date(thread.lastUserInboundAt as any).getTime()
    : 0;
  const isWithin24hWindow = Date.now() - lastInbound < 24 * 60 * 60 * 1000;

  // If outside 24h window, template is mandatory according to WhatsApp Business policy
  if (!isWithin24hWindow && !templateName) {
    throw new HttpsError(
      'failed-precondition',
      '24-hour reply window expired. You must use an approved WhatsApp template to reach this patient.'
    );
  }

  const result = await MessagingService.send(thread.patientPhone, message || '', {
    templateName,
    templateParams,
    isWithin24hWindow,
  });

  if (!result.success) {
    throw new HttpsError('internal', `Failed to send message: ${result.error}`);
  }

  const replyMsgId = result.messageId || `staff_${Date.now()}`;
  const outDoc: ConversationMessage = {
    id: replyMsgId,
    sender: 'clinic',
    text: message || `Template: ${templateName}`,
    timestamp: admin.firestore.FieldValue.serverTimestamp() as any,
    status: 'sent',
    channel: 'whatsapp',
    templateName,
  };

  const batch = db.batch();
  batch.set(threadDoc.ref.collection('messages').doc(replyMsgId), outDoc);
  batch.update(threadDoc.ref, {
    lastMessageText: outDoc.text,
    lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
    unreadCount: 0,
  });
  await batch.commit();

  return { success: true, messageId: replyMsgId };
});

// 4. Staff Inbox: Mark Resolved or Assign
export const manageConversationThread = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { patientId, action, assignedStaffId } = (request.data || {}) as {
    patientId: string;
    action: 'resolve' | 'reopen' | 'assign';
    assignedStaffId?: string;
  };

  const threadRef = db.collection(COLLECTIONS.CONVERSATIONS).doc(patientId);

  if (action === 'resolve') {
    await threadRef.update({
      status: 'resolved',
      isUrgent: false,
      unreadCount: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else if (action === 'reopen') {
    await threadRef.update({
      status: 'open',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else if (action === 'assign') {
    await threadRef.update({
      assignedStaffId: assignedStaffId || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return { success: true };
});

// 5. Recall Campaign: Get Eligible Candidates
export const getRecallCandidates = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const {
    clinicId,
    monthsSinceLastVisit = 6,
    doctorId,
    onlyAtRisk = false,
  } = (request.data || {}) as {
    clinicId?: string;
    monthsSinceLastVisit?: number;
    doctorId?: string;
    onlyAtRisk?: boolean;
  };

  const callerClinicId = request.auth.token.clinicId || 'default-clinic';
  const effectiveClinicId = clinicId || callerClinicId;

  const now = new Date();
  const cutoffDate = new Date(now.getTime() - monthsSinceLastVisit * 30 * 24 * 60 * 60 * 1000);
  const cutoffDateStr = cutoffDate.toISOString().split('T')[0];
  const fourteenDaysAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);

  // Query patients
  let pQuery = db.collection(COLLECTIONS.PATIENTS).where('clinicId', '==', effectiveClinicId);
  if (doctorId) {
    pQuery = pQuery.where('doctorId', '==', doctorId);
  }
  const pSnap = await pQuery.limit(200).get();

  const candidates = [];

  for (const doc of pSnap.docs) {
    const patient = doc.data() as PatientDocument;

    // Consent check
    if (patient.messagingConsent === false) continue;

    // 14-day anti-spam cooldown check
    const lastRecall = (patient as any).lastRecallSentAt
      ? new Date((patient as any).lastRecallSentAt.toDate ? (patient as any).lastRecallSentAt.toDate() : (patient as any).lastRecallSentAt)
      : null;
    if (lastRecall && lastRecall > fourteenDaysAgo) continue;

    let eligible = false;
    let reason = '';

    // A. Check at-risk treatment plan
    const planQuery = await db
      .collection(COLLECTIONS.TREATMENT_PLANS)
      .where('patientId', '==', doc.id)
      .where('status', '==', 'at_risk')
      .limit(1)
      .get();

    if (!planQuery.empty) {
      eligible = true;
      reason = 'At-Risk Treatment Plan';
    } else if (!onlyAtRisk) {
      // B. Check last appointment visit date
      const apptQuery = await db
        .collection(COLLECTIONS.APPOINTMENTS)
        .where('patientId', '==', doc.id)
        .orderBy('date', 'desc')
        .limit(1)
        .get();

      if (!apptQuery.empty) {
        const lastAppt = apptQuery.docs[0].data() as AppointmentDocument;
        if (lastAppt.date <= cutoffDateStr) {
          eligible = true;
          reason = `Last visit > ${monthsSinceLastVisit} months ago (${lastAppt.date})`;
        }
      } else {
        eligible = true;
        reason = 'No recorded completed visit';
      }
    }

    if (eligible) {
      candidates.push({
        patientId: doc.id,
        name: patient.name,
        phone: patient.phone,
        preferredLanguage: patient.preferredLanguage || 'en',
        reason,
      });
    }
  }

  return { success: true, count: candidates.length, candidates };
});

// 6. Recall Campaign: Execute Broadcast Send
export const triggerRecallCampaign = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { clinicId, name, templateName, patientIds } = (request.data || {}) as {
    clinicId?: string;
    name: string;
    templateName: string;
    patientIds: string[];
  };

  if (!name || !templateName || !patientIds || patientIds.length === 0) {
    throw new HttpsError('invalid-argument', 'name, templateName, and patientIds are required.');
  }

  const effectiveClinicId = clinicId || request.auth.token.clinicId || 'default-clinic';
  const campaignRef = db.collection(COLLECTIONS.RECALL_CAMPAIGNS).doc();

  let sentCount = 0;
  let skippedConsentCount = 0;
  let skippedRecentCount = 0;

  const fourteenDaysAgo = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000);

  // Fetch clinic info for booking link
  const clinicDoc = await db.collection(COLLECTIONS.CLINICS).doc(effectiveClinicId).get();
  const clinicName = clinicDoc.data()?.name || 'CareTrack Dental Clinic';
  const bookingLink = `${config.baseAppUrl}/bookWeb?clinic=${effectiveClinicId}`;

  for (const pid of patientIds) {
    try {
      const pDoc = await db.collection(COLLECTIONS.PATIENTS).doc(pid).get();
      if (!pDoc.exists) continue;
      const patient = pDoc.data() as PatientDocument;

      if (patient.messagingConsent === false) {
        skippedConsentCount++;
        continue;
      }

      const lastRecall = (patient as any).lastRecallSentAt
        ? new Date((patient as any).lastRecallSentAt.toDate ? (patient as any).lastRecallSentAt.toDate() : (patient as any).lastRecallSentAt)
        : null;
      if (lastRecall && lastRecall > fourteenDaysAgo) {
        skippedRecentCount++;
        continue;
      }

      const lang = patient.preferredLanguage || 'en';
      const template = TemplateRegistryService.getTemplate(templateName, lang);
      const params = [patient.name, clinicName, bookingLink];

      const res = await MessagingService.send(patient.phone || '', template?.body || '', {
        templateName,
        templateParams: params,
      });

      if (res.success) {
        sentCount++;
        await pDoc.ref.update({
          lastRecallSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } catch (sendErr) {
      console.error(`Error sending recall to patient ${pid}:`, sendErr);
    }
  }

  const campaignDoc: RecallCampaignDocument = {
    id: campaignRef.id,
    clinicId: effectiveClinicId,
    name,
    templateName,
    targetCount: patientIds.length,
    sentCount,
    skippedConsentCount,
    skippedRecentCount,
    repliedCount: 0,
    bookedCount: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
    status: 'completed',
  };

  await campaignRef.set(campaignDoc);

  await AuditService.log({
    clinicId: effectiveClinicId,
    userId: request.auth.uid,
    action: 'campaign.executed',
    entityType: 'staff',
    entityId: campaignRef.id,
    details: { sentCount, skippedConsentCount, skippedRecentCount },
  });

  return {
    success: true,
    campaignId: campaignRef.id,
    sentCount,
    skippedConsentCount,
    skippedRecentCount,
  };
});

// 7. Post-Visit Review Request (Max once per 90 days per patient)
export const sendReviewRequest = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { patientId, clinicId } = (request.data || {}) as { patientId: string; clinicId?: string };
  if (!patientId) {
    throw new HttpsError('invalid-argument', 'patientId is required.');
  }

  const pRef = db.collection(COLLECTIONS.PATIENTS).doc(patientId);
  const pDoc = await pRef.get();
  if (!pDoc.exists) {
    throw new HttpsError('not-found', 'Patient not found.');
  }

  const patient = pDoc.data() as PatientDocument;
  const ninetyDaysAgo = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);

  const lastReviewReq = (patient as any).lastReviewRequestSentAt
    ? new Date((patient as any).lastReviewRequestSentAt.toDate ? (patient as any).lastReviewRequestSentAt.toDate() : (patient as any).lastReviewRequestSentAt)
    : null;

  if (lastReviewReq && lastReviewReq > ninetyDaysAgo) {
    throw new HttpsError(
      'failed-precondition',
      'Review request was already sent to this patient in the past 90 days.'
    );
  }

  const effectiveClinicId = clinicId || patient.clinicId || 'default-clinic';
  const clinicDoc = await db.collection(COLLECTIONS.CLINICS).doc(effectiveClinicId).get();
  const clinicName = clinicDoc.data()?.name || 'CareTrack Dental';
  const googleReviewUrl = (clinicDoc.data() as any)?.googleReviewUrl || 'https://g.page/r/caretrack/review';

  const template = TemplateRegistryService.getTemplate('clinic_review_request', patient.preferredLanguage || 'en');
  const params = [patient.name, clinicName, googleReviewUrl];

  const res = await MessagingService.send(patient.phone || '', template?.body || '', {
    templateName: 'clinic_review_request',
    templateParams: params,
  });

  if (res.success) {
    await pRef.update({
      lastReviewRequestSentAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return { success: res.success, messageId: res.messageId };
});
