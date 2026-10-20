import { messaging } from '../config/index.js';

export interface PushResult {
  success: boolean;
  messageId?: string;
  error?: string;
}

export class PushService {
  public static async sendPush(
    token: string,
    title: string,
    body: string,
    data: Record<string, string> = {}
  ): Promise<PushResult> {
    if (!token || token.trim().length === 0) {
      return {
        success: false,
        error: 'No FCM device token provided',
      };
    }

    try {
      const response = await messaging.send({
        token,
        notification: {
          title,
          body,
        },
        data: {
          ...data,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'caretrack_reminders',
          },
        },
      });

      return {
        success: true,
        messageId: response,
      };
    } catch (err: any) {
      return {
        success: false,
        error: err.message || 'FCM notification dispatch failed',
      };
    }
  }
}
