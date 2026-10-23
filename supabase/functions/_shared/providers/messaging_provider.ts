// Messaging Provider Abstraction for WhatsApp Cloud API, Telegram fallback, and SMS stub
import { safeLog, safeError } from "../logger.ts";

export interface SendResult {
  providerMessageId: string;
}

export interface MessagingProvider {
  name: string;
  sendTemplate(
    to: string,
    templateName: string,
    language: string,
    variables?: Record<string, string>
  ): Promise<SendResult>;
  sendTextMessage(to: string, text: string): Promise<SendResult>;
}

export class WhatsAppProvider implements MessagingProvider {
  name = "whatsapp";
  private phoneNumberId: string;
  private accessToken: string;

  constructor() {
    this.phoneNumberId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID") || "mock-phone-id";
    this.accessToken = Deno.env.get("WHATSAPP_ACCESS_TOKEN") || "mock-access-token";
  }

  async sendTemplate(
    to: string,
    templateName: string,
    language = "en",
    variables: Record<string, string> = {}
  ): Promise<SendResult> {
    const cleanPhone = to.replace("+", "");

    // Mock bypass when running in demo/offline mode
    if (this.accessToken === "mock-access-token") {
      safeLog(`[Mock WhatsApp] Template '${templateName}' sent to ${to}`, { variables });
      return { providerMessageId: `mock_wamid_${Date.now()}` };
    }

    const url = `https://graph.facebook.com/v21.0/${this.phoneNumberId}/messages`;
    
    // Map variables to Meta template body components
    const bodyParameters = Object.values(variables).map((val) => ({
      type: "text",
      text: val,
    }));

    const payload = {
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: cleanPhone,
      type: "template",
      template: {
        name: templateName,
        language: { code: language },
        components: bodyParameters.length > 0 ? [
          {
            type: "body",
            parameters: bodyParameters,
          },
        ] : [],
      },
    };

    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const errText = await res.text();
      safeError(`WhatsApp Cloud API error (${res.status})`, errText);
      throw new Error(`WhatsApp API error: ${res.status}`);
    }

    const data = await res.json();
    const id = data?.messages?.[0]?.id || `wamid_${Date.now()}`;
    return { providerMessageId: id };
  }

  async sendTextMessage(to: string, text: string): Promise<SendResult> {
    const cleanPhone = to.replace("+", "");

    if (this.accessToken === "mock-access-token") {
      safeLog(`[Mock WhatsApp] Free-form message sent to ${to}: ${text.slice(0, 30)}...`);
      return { providerMessageId: `mock_wamid_${Date.now()}` };
    }

    const url = `https://graph.facebook.com/v21.0/${this.phoneNumberId}/messages`;
    const payload = {
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: cleanPhone,
      type: "text",
      text: { preview_url: false, body: text },
    };

    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const errText = await res.text();
      safeError(`WhatsApp API free-form error (${res.status})`, errText);
      throw new Error(`WhatsApp API free-form error: ${res.status}`);
    }

    const data = await res.json();
    return { providerMessageId: data?.messages?.[0]?.id || `wamid_${Date.now()}` };
  }
}

export class TelegramProvider implements MessagingProvider {
  name = "telegram";
  private botToken: string;

  constructor() {
    this.botToken = Deno.env.get("TELEGRAM_BOT_TOKEN") || "mock-telegram-token";
  }

  async sendTemplate(
    to: string,
    templateName: string,
    _language = "en",
    variables: Record<string, string> = {}
  ): Promise<SendResult> {
    // Format variables into standard message
    const formatted = `[${templateName}] ` + Object.entries(variables).map(([k, v]) => `${k}: ${v}`).join(", ");
    return this.sendTextMessage(to, formatted);
  }

  async sendTextMessage(to: string, text: string): Promise<SendResult> {
    if (this.botToken === "mock-telegram-token") {
      safeLog(`[Mock Telegram] Sent to ${to}: ${text.slice(0, 30)}...`);
      return { providerMessageId: `mock_tg_${Date.now()}` };
    }

    const url = `https://api.telegram.org/bot${this.botToken}/sendMessage`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: to, text }),
    });

    if (!res.ok) {
      throw new Error(`Telegram API error: ${res.status}`);
    }
    const data = await res.json();
    return { providerMessageId: String(data.result?.message_id || Date.now()) };
  }
}

/**
 * India SMS Provider Stub:
 * TODO: For production deployment with SMS in India, telecommunication regulations mandate
 * TRAI Distributed Ledger Technology (DLT) registration. Clinics must register entity (PE ID),
 * Header (Sender ID like "SMLCAR"), and obtain approved Content Template IDs before sending SMS.
 */
export class IndiaSmsStubProvider implements MessagingProvider {
  name = "india_sms";

  async sendTemplate(to: string, templateName: string): Promise<SendResult> {
    safeLog(`[India SMS Stub] Template ${templateName} routed for ${to}. (Requires TRAI DLT Principal Entity and Template ID registration)`);
    return { providerMessageId: `sms_dlt_stub_${Date.now()}` };
  }

  async sendTextMessage(to: string, text: string): Promise<SendResult> {
    safeLog(`[India SMS Stub] Text routed for ${to}: ${text.slice(0, 30)}...`);
    return { providerMessageId: `sms_dlt_stub_${Date.now()}` };
  }
}

export function getMessagingProvider(): MessagingProvider {
  const providerType = (Deno.env.get("MESSAGING_PROVIDER") || "whatsapp").toLowerCase();
  switch (providerType) {
    case "telegram":
      return new TelegramProvider();
    case "sms":
    case "india_sms":
      return new IndiaSmsStubProvider();
    case "whatsapp":
    default:
      return new WhatsAppProvider();
  }
}
