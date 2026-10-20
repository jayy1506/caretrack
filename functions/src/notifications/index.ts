import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import { auth } from '../config/index.js';
import { NotificationService } from '../services/notificationService.js';
import { MessagingService } from '../services/messagingService.js';

export const sendDirectMessage = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to send messages.');
  }

  const { doctorId, patientId, phone, email, message, subject } = request.data || {};
  const callerUid = request.auth.uid;
  const callerRole = request.auth.token.role;

  if (callerRole !== 'admin' && doctorId && doctorId !== callerUid) {
    throw new HttpsError('permission-denied', 'You cannot send messages on behalf of another practitioner.');
  }

  return await NotificationService.dispatch({
    doctorId: doctorId || callerUid,
    patientId: patientId || undefined,
    type: 'custom_message',
    messaging: phone ? { to: phone, message } : undefined,
    email: email
      ? {
          to: email,
          subject: subject || 'CareTrack Clinic Message',
          html: `<p>${(message || '').replace(/\n/g, '<br>')}</p>`,
        }
      : undefined,
  });
});

/**
 * Protected HTTP API endpoint for sending clinic messages.
 * Requires a valid Firebase Auth ID token from an active doctor or admin.
 * Replaces the previously unauthenticated public endpoint.
 */
export const apiSendMessage = onRequest({ cors: true }, async (req, res) => {
  try {
    // 1. Verify Authorization Bearer token
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        success: false,
        error: 'Missing or invalid Authorization header. Format: Bearer <Firebase_ID_Token>',
      });
      return;
    }

    const idToken = authHeader.split('Bearer ')[1].trim();
    let decodedToken;
    try {
      decodedToken = await auth.verifyIdToken(idToken);
    } catch (authErr) {
      res.status(401).json({ success: false, error: 'Unauthorized: Invalid or expired Firebase ID token' });
      return;
    }

    // 2. Validate Doctor or Admin role
    const userRole = decodedToken.role;
    if (userRole !== 'doctor' && userRole !== 'admin') {
      res.status(403).json({
        success: false,
        error: 'Forbidden: Caller must have doctor or admin privileges to send messages',
      });
      return;
    }

    // 3. Process Message Dispatch
    const { to, message, templateName, templateParams, isWithin24hWindow } = req.body || {};
    if (!to || !message) {
      res.status(400).json({ success: false, error: 'Missing required "to" or "message" parameter' });
      return;
    }

    const result = await MessagingService.send(to, message, {
      templateName,
      templateParams,
      isWithin24hWindow,
    });

    if (result.success) {
      res.status(200).json({
        success: true,
        messageId: result.messageId,
      });
    } else {
      res.status(result.statusCode || 400).json({
        success: false,
        error: result.error,
      });
    }
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message || 'Internal server error' });
  }
});
