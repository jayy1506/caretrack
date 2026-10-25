// Email provider implementation supporting Brevo HTTP API and Twilio Comms Email API
import { safeLog, safeError } from "../logger.ts";

export interface EmailSendParams {
  toEmail: string;
  toName?: string;
  subject: string;
  htmlContent: string;
  senderName?: string;
  senderEmail?: string;
}

export async function sendEmail(params: EmailSendParams): Promise<{ messageId: string }> {
  const emailProvider = (Deno.env.get("EMAIL_PROVIDER") || "").toLowerCase();
  const twilioSid = Deno.env.get("TWILIO_ACCOUNT_SID");
  const twilioAuth = Deno.env.get("TWILIO_AUTH_TOKEN");
  const brevoApiKey = Deno.env.get("BREVO_API_KEY");

  // Determine provider: Twilio if requested or configured, otherwise Brevo
  const useTwilio = emailProvider === "twilio" || (!!twilioSid && !!twilioAuth && !brevoApiKey && emailProvider !== "brevo");

  if (useTwilio && twilioSid && twilioAuth) {
    const senderEmail = params.senderEmail || Deno.env.get("TWILIO_EMAIL_FROM_ADDRESS") || `${twilioSid}@twilio.email`;
    const senderName = params.senderName || Deno.env.get("TWILIO_EMAIL_FROM_NAME") || "CareTrack Clinic";

    // Mock bypass when running in demo/offline mode
    if (twilioAuth === "mock-auth-token" || twilioSid === "mock-sid") {
      safeLog(`[Mock Twilio Email] To: [REDACTED_PII], Subject: "${params.subject}"`);
      return { messageId: `mock_twilio_email_${Date.now()}` };
    }

    const authHeader = "Basic " + btoa(`${twilioSid}:${twilioAuth}`);
    const payload = {
      from: { address: senderEmail, name: senderName },
      to: [{ address: params.toEmail, name: params.toName }],
      content: {
        subject: params.subject,
        html: params.htmlContent,
      },
    };

    const res = await fetch("https://comms.twilio.com/v1/Emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: authHeader,
      },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const errText = await res.text();
      safeError(`Twilio Comms Email error (${res.status})`, errText);
      throw new Error(`Twilio Email error: ${res.status}`);
    }

    const data = await res.json().catch(() => ({}));
    return { messageId: data.operationId || `twilio_email_${Date.now()}` };
  }

  // Default / fallback to Brevo
  const senderEmail = params.senderEmail || Deno.env.get("BREVO_SENDER_EMAIL") || "notifications@caretrack.local";
  const senderName = params.senderName || "CareTrack Clinic";

  if (!brevoApiKey || brevoApiKey === "mock-brevo-key") {
    safeLog(`[Mock Email] To: [REDACTED_PII], Subject: "${params.subject}"`);
    return { messageId: `mock_email_${Date.now()}` };
  }

  const url = "https://api.brevo.com/v3/smtp/email";
  const payload = {
    sender: { name: senderName, email: senderEmail },
    to: [{ email: params.toEmail, name: params.toName || "Patient" }],
    subject: params.subject,
    htmlContent: params.htmlContent,
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "api-key": brevoApiKey,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const errText = await res.text();
    safeError(`Brevo API error (${res.status})`, errText);
    throw new Error(`Email provider error: ${res.status}`);
  }

  const data = await res.json();
  return { messageId: data.messageId || `brevo_${Date.now()}` };
}
