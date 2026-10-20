import * as admin from 'firebase-admin';
import { db, COLLECTIONS } from '../config/index.js';
import { NotificationType } from '../types/index.js';
import { sendEmail } from './emailService.js';
import { MessagingService, MessagingOptions } from './messagingService.js';
import { PushService } from './pushService.js';

export interface DispatchNotificationParams {
  doctorId: string;
  patientId?: string;
  appointmentId?: string;
  type: NotificationType;
  messagingConsent?: boolean;
  // Channels to attempt
  email?: {
    to: string;
    subject: string;
    html: string;
  };
  sms?: {
    to: string;
    message: string;
    opts?: MessagingOptions;
  };
  messaging?: {
    to: string;
    message: string;
    opts?: MessagingOptions;
  };
  push?: {
    token: string;
    title: string;
    body: string;
    data?: Record<string, string>;
    isDoctorAlert?: boolean;
  };
}

export type ChannelType = 'email' | 'messaging' | 'sms' | 'push';
export type ChannelStatus = 'sent' | 'failed' | 'skipped';

export interface ChannelDispatchSummary {
  channel: ChannelType;
  status: ChannelStatus;
  providerMessageId?: string;
  error?: string;
  recipient: string;
}

/**
 * Mask PII for HIPAA/privacy compliance before logging to database
 */
export function maskRecipient(raw: string, channel: ChannelType): string {
  if (!raw) return 'anonymous';
  const trimmed = raw.trim();

  if (channel === 'email' || trimmed.includes('@')) {
    const parts = trimmed.split('@');
    const local = parts[0] || '';
    const domain = parts[1] || '';
    if (local.length <= 2) {
      return `${local[0] || '*'}***@${domain}`;
    }
    return `${local[0]}***${local[local.length - 1]}@${domain}`;
  }

  if (channel === 'sms' || channel === 'messaging') {
    if (trimmed.length <= 4) {
      return '****';
    }
    const last4 = trimmed.slice(-4);
    const prefix = trimmed.startsWith('+') ? trimmed.slice(0, 3) : '';
    return `${prefix}******${last4}`;
  }

  // Push token
  if (trimmed.length > 10) {
    return `${trimmed.slice(0, 4)}...${trimmed.slice(-4)}`;
  }

  return 'masked_token';
}

/**
 * Executes an async operation with retry for transient (5xx / network) failures.
 * Does NOT retry 4xx client errors.
 */
async function executeWithRetry<T extends { success: boolean; messageId?: string; error?: string; statusCode?: number }>(
  fn: () => Promise<T>,
  maxRetries = 2
): Promise<T> {
  let attempt = 0;
  while (true) {
    try {
      const res = await fn();
      if (res.success) {
        return res;
      }

      const code = res.statusCode;
      const isTransient = !code || (code >= 500 && code < 600);
      attempt++;

      if (attempt > maxRetries || !isTransient) {
        return res;
      }

      const delay = Math.pow(2, attempt - 1) * 500;
      await new Promise((resolve) => setTimeout(resolve, delay));
    } catch (err: any) {
      attempt++;
      if (attempt > maxRetries) {
        return {
          success: false,
          error: err?.message || 'Transient failure exceeded max retries',
        } as T;
      }
      const delay = Math.pow(2, attempt - 1) * 500;
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }
}

export class NotificationService {
  /**
   * Dispatches notifications in parallel across all requested channels.
   * Uses Promise.allSettled so a failure on one channel never blocks others.
   * Masks PII before persisting to /notifications collection.
   */
  public static async dispatch(params: DispatchNotificationParams): Promise<ChannelDispatchSummary[]> {
    const results: ChannelDispatchSummary[] = [];

    // Verify patient messaging consent if sending patient-facing communications
    let hasConsent = params.messagingConsent;
    if (hasConsent === undefined && params.patientId) {
      try {
        const patientDoc = await db.collection(COLLECTIONS.PATIENTS).doc(params.patientId).get();
        if (patientDoc.exists) {
          const patientData = patientDoc.data();
          hasConsent = patientData?.messagingConsent === true;
        } else {
          hasConsent = false;
        }
      } catch (err) {
        console.error('Error checking patient consent:', err);
        hasConsent = false;
      }
    }

    const tasks: Promise<ChannelDispatchSummary>[] = [];

    // 1. Email Channel
    if (params.email && params.email.to) {
      const emailRecipient = params.email.to;
      const emailParams = params.email;

      tasks.push(
        (async (): Promise<ChannelDispatchSummary> => {
          if (hasConsent !== true) {
            const summary: ChannelDispatchSummary = {
              channel: 'email',
              status: 'skipped',
              recipient: maskRecipient(emailRecipient, 'email'),
              error: 'Patient opted out of notifications (messagingConsent !== true)',
            };
            await this.logNotificationRecord(params, summary);
            return summary;
          }

          const res = await executeWithRetry(async () => {
            return await sendEmail({
              to: emailParams.to,
              subject: emailParams.subject,
              html: emailParams.html,
            });
          });

          const summary: ChannelDispatchSummary = {
            channel: 'email',
            status: res.success ? 'sent' : 'failed',
            providerMessageId: res.messageId,
            error: res.error,
            recipient: maskRecipient(emailRecipient, 'email'),
          };
          await this.logNotificationRecord(params, summary);
          return summary;
        })()
      );
    }

    // 2. Messaging / SMS Channel
    const messagingPayload = params.messaging || params.sms;
    if (messagingPayload && messagingPayload.to) {
      const msgRecipient = messagingPayload.to;
      const msgBody = messagingPayload.message;
      const msgOpts = messagingPayload.opts;

      tasks.push(
        (async (): Promise<ChannelDispatchSummary> => {
          if (hasConsent !== true) {
            const summary: ChannelDispatchSummary = {
              channel: 'messaging',
              status: 'skipped',
              recipient: maskRecipient(msgRecipient, 'messaging'),
              error: 'Patient opted out of notifications (messagingConsent !== true)',
            };
            await this.logNotificationRecord(params, summary);
            return summary;
          }

          const res = await executeWithRetry(async () => {
            return await MessagingService.send(msgRecipient, msgBody, msgOpts);
          });

          const summary: ChannelDispatchSummary = {
            channel: 'messaging',
            status: res.success ? 'sent' : 'failed',
            providerMessageId: res.messageId,
            error: res.error,
            recipient: maskRecipient(msgRecipient, 'messaging'),
          };
          await this.logNotificationRecord(params, summary);
          return summary;
        })()
      );
    }

    // 3. Push Channel (FCM)
    if (params.push && params.push.token) {
      const pushToken = params.push.token;
      const pushPayload = params.push;

      tasks.push(
        (async (): Promise<ChannelDispatchSummary> => {
          // Push notifications sent to doctors do not require patient messaging consent
          if (!pushPayload.isDoctorAlert && hasConsent !== true) {
            const summary: ChannelDispatchSummary = {
              channel: 'push',
              status: 'skipped',
              recipient: maskRecipient(pushToken, 'push'),
              error: 'Patient opted out of push notifications (messagingConsent !== true)',
            };
            await this.logNotificationRecord(params, summary);
            return summary;
          }

          const res = await executeWithRetry(async () => {
            return await PushService.sendPush(
              pushPayload.token,
              pushPayload.title,
              pushPayload.body,
              pushPayload.data
            );
          });

          const summary: ChannelDispatchSummary = {
            channel: 'push',
            status: res.success ? 'sent' : 'failed',
            providerMessageId: res.messageId,
            error: res.error,
            recipient: maskRecipient(pushToken, 'push'),
          };
          await this.logNotificationRecord(params, summary);
          return summary;
        })()
      );
    }

    // Parallel execution with Promise.allSettled
    const settled = await Promise.allSettled(tasks);
    for (const result of settled) {
      if (result.status === 'fulfilled') {
        results.push(result.value);
      } else {
        console.error('Unhandled channel failure in notification dispatch:', result.reason);
      }
    }

    return results;
  }

  /**
   * Writes audit record to /notifications collection with masked recipient
   */
  private static async logNotificationRecord(
    params: DispatchNotificationParams,
    summary: ChannelDispatchSummary
  ): Promise<void> {
    try {
      const docRef = db.collection(COLLECTIONS.NOTIFICATIONS).doc();
      await docRef.set({
        id: docRef.id,
        doctorId: params.doctorId,
        patientId: params.patientId || null,
        appointmentId: params.appointmentId || null,
        channel: summary.channel,
        type: params.type,
        recipient: summary.recipient,
        status: summary.status,
        providerMessageId: summary.providerMessageId || null,
        error: summary.error || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.error('Failed to write notification audit doc:', err);
    }
  }
}
