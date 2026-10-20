import { config } from '../config/index.js';

export interface SendResult {
  success: boolean;
  messageId?: string;
  error?: string;
  statusCode?: number;
}

export interface MessagingOptions {
  templateName?: 'appointment_reminder' | 'appointment_confirmation' | 'welcome' | string;
  templateParams?: string[];
  isWithin24hWindow?: boolean;
  telegramChatId?: string;
}

export interface MessagingProvider {
  send(to: string, body: string, opts?: MessagingOptions): Promise<SendResult>;
}

/**
 * Normalizes phone numbers to E.164 standard (+[country][number]).
 * Defaults to +91 (India) for 10-digit inputs.
 * Rejects invalid phone numbers with a clear descriptive error.
 */
export function normalizePhoneNumber(raw: string): { valid: boolean; normalized?: string; error?: string } {
  if (!raw || typeof raw !== 'string') {
    return { valid: false, error: 'Phone number is required and must be a string' };
  }

  const trimmed = raw.trim();
  const cleaned = trimmed.replace(/[^\d+]/g, '');

  if (cleaned.startsWith('+')) {
    const digitsOnly = cleaned.slice(1);
    // Standard E.164 requires 7 to 15 digits without leading zero
    if (!/^[1-9]\d{6,14}$/.test(digitsOnly)) {
      return {
        valid: false,
        error: 'Invalid international phone number. Must follow E.164 (+[country code][number], 7-15 digits)',
      };
    }
    return { valid: true, normalized: cleaned };
  }

  // 10-digit Indian mobile number
  if (/^[6-9]\d{9}$/.test(cleaned) || cleaned.length === 10) {
    return { valid: true, normalized: `+91${cleaned}` };
  }

  // 12-digit Indian number with 91 prefix but missing '+'
  if (cleaned.length === 12 && cleaned.startsWith('91')) {
    return { valid: true, normalized: `+${cleaned}` };
  }

  return {
    valid: false,
    error: 'Invalid phone number: must be a 10-digit Indian phone number or valid E.164 format (+[country][number])',
  };
}

/**
 * WhatsApp Cloud API Provider (Meta Graph API v20.0)
 * Uses approved templates for business-initiated notifications, and free-form text within 24h user reply window.
 */
export class WhatsAppProvider implements MessagingProvider {
  public async send(to: string, body: string, opts?: MessagingOptions): Promise<SendResult> {
    const phoneNorm = normalizePhoneNumber(to);
    if (!phoneNorm.valid || !phoneNorm.normalized) {
      return {
        success: false,
        error: phoneNorm.error || 'Invalid recipient phone number',
        statusCode: 400,
      };
    }

    if (!config.whatsappPhoneNumberId || !config.whatsappAccessToken) {
      return {
        success: false,
        error: 'WhatsApp Cloud API credentials missing (WHATSAPP_PHONE_NUMBER_ID or WHATSAPP_ACCESS_TOKEN not set)',
        statusCode: 500,
      };
    }

    // Meta WhatsApp Cloud API recipient requires number without '+' sign
    const recipientDigits = phoneNorm.normalized.replace(/^\+/, '');
    const url = `https://graph.facebook.com/v20.0/${config.whatsappPhoneNumberId}/messages`;

    let payload: Record<string, any>;

    if (opts?.isWithin24hWindow) {
      // Free-form text within the active 24-hour customer conversation window
      payload = {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: recipientDigits,
        type: 'text',
        text: {
          preview_url: false,
          body: body,
        },
      };
    } else {
      // Business-initiated message: must use an approved template
      const templateName = opts?.templateName || 'appointment_reminder';
      const templateParams = opts?.templateParams || [body];

      payload = {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: recipientDigits,
        type: 'template',
        template: {
          name: templateName,
          language: {
            code: 'en_US',
          },
          components: [
            {
              type: 'body',
              parameters: templateParams.map((param) => ({
                type: 'text',
                text: param,
              })),
            },
          ],
        },
      };
    }

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${config.whatsappAccessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      const data: any = await response.json().catch(() => ({}));

      if (!response.ok) {
        const errorMsg = data?.error?.message || `WhatsApp Cloud API error (HTTP ${response.status})`;
        return {
          success: false,
          error: errorMsg,
          statusCode: response.status,
        };
      }

      const messageId = data?.messages?.[0]?.id || 'wa_sent';
      return {
        success: true,
        messageId: messageId,
        statusCode: 200,
      };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Network exception communicating with WhatsApp Cloud API',
        statusCode: 503,
      };
    }
  }
}

/**
 * Telegram Bot Provider (Optional fallback/alternative)
 */
export class TelegramProvider implements MessagingProvider {
  public async send(to: string, body: string, opts?: MessagingOptions): Promise<SendResult> {
    if (!config.telegramBotToken) {
      return {
        success: false,
        error: 'Telegram bot token missing (TELEGRAM_BOT_TOKEN not configured)',
        statusCode: 500,
      };
    }

    const chatId = opts?.telegramChatId || to;
    if (!chatId) {
      return {
        success: false,
        error: 'Telegram recipient chatId missing',
        statusCode: 400,
      };
    }

    const url = `https://api.telegram.org/bot${config.telegramBotToken}/sendMessage`;

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: chatId,
          text: body,
          parse_mode: 'HTML',
        }),
      });

      const data: any = await response.json().catch(() => ({}));

      if (!response.ok || !data?.ok) {
        return {
          success: false,
          error: data?.description || `Telegram API error (HTTP ${response.status})`,
          statusCode: response.status,
        };
      }

      return {
        success: true,
        messageId: String(data?.result?.message_id || 'tg_sent'),
        statusCode: 200,
      };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Network exception communicating with Telegram Bot API',
        statusCode: 503,
      };
    }
  }
}

/**
 * Stubs for SMS providers (MSG91 / Fast2SMS)
 * TODO: Implement MSG91 / Fast2SMS provider once DLT registration (TRAI Enterprise ID, Sender ID,
 * and approved template IDs) is completed under Indian telecom regulations.
 */
export class Msg91ProviderStub implements MessagingProvider {
  public async send(to: string, body: string, opts?: MessagingOptions): Promise<SendResult> {
    // TODO: Connect MSG91 Flow API after DLT registration
    return {
      success: false,
      error: 'MSG91 provider requires TRAI DLT registration and approved template IDs before deployment.',
      statusCode: 501,
    };
  }
}

export class Fast2SmsProviderStub implements MessagingProvider {
  public async send(to: string, body: string, opts?: MessagingOptions): Promise<SendResult> {
    // TODO: Connect Fast2SMS Quick/DLT SMS API after DLT registration
    return {
      success: false,
      error: 'Fast2SMS provider requires DLT Entity ID and Template ID registration.',
      statusCode: 501,
    };
  }
}

/**
 * None/Mock Provider for local testing and disabled messaging
 */
export class NoneProvider implements MessagingProvider {
  public async send(to: string, body: string, opts?: MessagingOptions): Promise<SendResult> {
    return {
      success: true,
      messageId: `mock_msg_${Date.now()}`,
      statusCode: 200,
    };
  }
}

/**
 * Main Messaging Service
 * Selects provider based on MESSAGING_PROVIDER environment variable ('whatsapp' | 'telegram' | 'none').
 */
export class MessagingService {
  private static provider: MessagingProvider | null = null;

  public static getProvider(): MessagingProvider {
    if (this.provider) {
      return this.provider;
    }

    const providerType = config.messagingProvider;
    switch (providerType) {
      case 'whatsapp':
        this.provider = new WhatsAppProvider();
        break;
      case 'telegram':
        this.provider = new TelegramProvider();
        break;
      case 'none':
        this.provider = new NoneProvider();
        break;
      default:
        this.provider = new WhatsAppProvider();
        break;
    }
    return this.provider;
  }

  public static setProvider(customProvider: MessagingProvider): void {
    this.provider = customProvider;
  }

  public static isConfigured(): boolean {
    const providerType = config.messagingProvider;
    if (providerType === 'whatsapp') {
      return Boolean(config.whatsappPhoneNumberId && config.whatsappAccessToken);
    }
    if (providerType === 'telegram') {
      return Boolean(config.telegramBotToken);
    }
    return providerType === 'none';
  }

  /**
   * Main messaging dispatch entry point.
   */
  public static async send(to: string, body: string, opts?: MessagingOptions): Promise<SendResult> {
    return this.getProvider().send(to, body, opts);
  }

  /**
   * Alias for backward compatibility with previous smsService callers.
   */
  public static async sendSms(to: string, message: string, opts?: MessagingOptions): Promise<SendResult> {
    return this.send(to, message, opts);
  }
}

// Export SmsService as alias to ensure zero breakages across legacy modules
export const SmsService = MessagingService;
