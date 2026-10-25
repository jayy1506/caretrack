// Messaging Provider Abstraction for WhatsApp Cloud API, Twilio (WhatsApp & SMS), Telegram, and India SMS Stub
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

/**
 * Twilio WhatsApp Provider:
 * Uses Twilio Programmable Messaging API with WhatsApp templates (Content API) or session messages.
 */
export class TwilioWhatsAppProvider implements MessagingProvider {
  name = "twilio_whatsapp";
  private accountSid: string;
  private authToken: string;
  private fromNumber: string;
  private defaultContentSid: string;

  constructor() {
    this.accountSid = Deno.env.get("TWILIO_ACCOUNT_SID") || "mock-sid";
    this.authToken = Deno.env.get("TWILIO_AUTH_TOKEN") || "mock-token";
    this.fromNumber = Deno.env.get("TWILIO_WHATSAPP_NUMBER") || "+17372212163";
    this.defaultContentSid = Deno.env.get("TWILIO_WHATSAPP_CONTENT_SID") || "";
  }

  async sendTemplate(
    to: string,
    templateName: string,
    _language = "en",
    variables: Record<string, string> = {}
  ): Promise<SendResult> {
    if (this.authToken === "mock-token" || this.accountSid === "mock-sid") {
      safeLog(`[Mock Twilio WhatsApp] Template '${templateName}' sent to ${to}`, { variables });
      return { providerMessageId: `mock_twilio_wa_${Date.now()}` };
    }

    const formattedTo = to.startsWith("whatsapp:") ? to : `whatsapp:${to}`;
    const formattedFrom = this.fromNumber.startsWith("whatsapp:") ? this.fromNumber : `whatsapp:${this.fromNumber}`;

    const bodyParams = new URLSearchParams({
      To: formattedTo,
      From: formattedFrom,
    });

    // If templateName starts with HX it is a Twilio Content SID, otherwise check defaultContentSid
    const contentSid = templateName.startsWith("HX") ? templateName : this.defaultContentSid;

    if (contentSid) {
      bodyParams.append("ContentSid", contentSid);
      if (Object.keys(variables).length > 0) {
        bodyParams.append("ContentVariables", JSON.stringify(variables));
      }
    } else {
      const body = Object.entries(variables).length > 0
        ? `[${templateName}] ` + Object.entries(variables).map(([k, v]) => `${k}: ${v}`).join(", ")
        : `Notification: ${templateName}`;
      bodyParams.append("Body", body);
    }

    const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${this.accountSid}/Messages.json`, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Authorization: "Basic " + btoa(`${this.accountSid}:${this.authToken}`),
      },
      body: bodyParams.toString(),
    });

    if (!res.ok) {
      const errText = await res.text();
      safeError(`Twilio WhatsApp error (${res.status})`, errText);
      throw new Error(`Twilio WhatsApp error: ${res.status}`);
    }

    const data = await res.json();
    return { providerMessageId: data.sid || `twilio_wa_${Date.now()}` };
  }

  async sendTextMessage(to: string, text: string): Promise<SendResult> {
    if (this.authToken === "mock-token" || this.accountSid === "mock-sid") {
      safeLog(`[Mock Twilio WhatsApp] Text sent to ${to}: ${text.slice(0, 30)}...`);
      return { providerMessageId: `mock_twilio_wa_${Date.now()}` };
    }

    const formattedTo = to.startsWith("whatsapp:") ? to : `whatsapp:${to}`;
    const formattedFrom = this.fromNumber.startsWith("whatsapp:") ? this.fromNumber : `whatsapp:${this.fromNumber}`;

    const bodyParams = new URLSearchParams({
      To: formattedTo,
      From: formattedFrom,
      Body: text,
    });

    const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${this.accountSid}/Messages.json`, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Authorization: "Basic " + btoa(`${this.accountSid}:${this.authToken}`),
      },
      body: bodyParams.toString(),
    });

    if (!res.ok) {
      const errText = await res.text();
      safeError(`Twilio WhatsApp text error (${res.status})`, errText);
      throw new Error(`Twilio WhatsApp text error: ${res.status}`);
    }

    const data = await res.json();
    return { providerMessageId: data.sid || `twilio_wa_${Date.now()}` };
  }
}

/**
 * Twilio SMS Provider:
 * Direct SMS delivery via Twilio Programmable SMS API.
 */
export class TwilioSmsProvider implements MessagingProvider {
  name = "twilio_sms";
  private accountSid: string;
  private authToken: string;
  private fromNumber: string;

  constructor() {
    this.accountSid = Deno.env.get("TWILIO_ACCOUNT_SID") || "mock-sid";
    this.authToken = Deno.env.get("TWILIO_AUTH_TOKEN") || "mock-token";
    this.fromNumber = Deno.env.get("TWILIO_PHONE_NUMBER") || "+17372212163";
  }

  async sendTemplate(
    to: string,
    templateName: string,
    _language = "en",
    variables: Record<string, string> = {}
  ): Promise<SendResult> {
    if (this.authToken === "mock-token" || this.accountSid === "mock-sid") {
      safeLog(`[Mock Twilio SMS] Template '${templateName}' sent to ${to}`, { variables });
      return { providerMessageId: `mock_twilio_sms_${Date.now()}` };
    }

    let body = "";
    if (variables.clinic_name && variables.starts_at) {
      body = `Reminder: Appt at ${variables.clinic_name} on ${variables.starts_at}. ${variables.confirm_link ? `Confirm: ${variables.confirm_link}` : ""}`.trim();
    } else if (Object.keys(variables).length > 0) {
      body = `[${templateName}] ` + Object.entries(variables).map(([k, v]) => `${k}: ${v}`).join(", ");
    } else {
      body = `Notification from CareTrack: ${templateName}`;
    }

    return this.sendTextMessage(to, body);
  }

  async sendTextMessage(to: string, text: string): Promise<SendResult> {
    if (this.authToken === "mock-token" || this.accountSid === "mock-sid") {
      safeLog(`[Mock Twilio SMS] Text sent to ${to}: ${text.slice(0, 30)}...`);
      return { providerMessageId: `mock_twilio_sms_${Date.now()}` };
    }

    const cleanTo = to.startsWith("+") ? to : `+${to}`;
    const bodyParams = new URLSearchParams({
      To: cleanTo,
      From: this.fromNumber,
      Body: text,
    });

    const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${this.accountSid}/Messages.json`, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Authorization: "Basic " + btoa(`${this.accountSid}:${this.authToken}`),
      },
      body: bodyParams.toString(),
    });

    if (!res.ok) {
      const errText = await res.text();
      safeError(`Twilio SMS error (${res.status})`, errText);
      throw new Error(`Twilio SMS error: ${res.status}`);
    }

    const data = await res.json();
    return { providerMessageId: data.sid || `twilio_sms_${Date.now()}` };
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
 * TRAI Distributed Ledger Technology (DLT) reference stub.
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

export function getMessagingProvider(providerOverride?: string): MessagingProvider {
  const providerType = (providerOverride || Deno.env.get("MESSAGING_PROVIDER") || "whatsapp").toLowerCase();
  switch (providerType) {
    case "twilio_whatsapp":
    case "twilio":
      return new TwilioWhatsAppProvider();
    case "twilio_sms":
      return new TwilioSmsProvider();
    case "telegram":
      return new TelegramProvider();
    case "india_sms":
      return new IndiaSmsStubProvider();
    case "sms":
      if (Deno.env.get("TWILIO_ACCOUNT_SID")) {
        return new TwilioSmsProvider();
      }
      return new IndiaSmsStubProvider();
    case "whatsapp":
    default:
      if (Deno.env.get("WHATSAPP_ACCESS_TOKEN") === "mock-access-token" && Deno.env.get("TWILIO_ACCOUNT_SID")) {
        return new TwilioWhatsAppProvider();
      }
      return new WhatsAppProvider();
  }
}
