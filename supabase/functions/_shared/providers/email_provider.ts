// Email provider implementation using Brevo HTTP API (and Gmail SMTP alternative)
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
  const brevoApiKey = Deno.env.get("BREVO_API_KEY");
  const senderEmail = params.senderEmail || Deno.env.get("BREVO_SENDER_EMAIL") || "notifications@caretrack.local";
  const senderName = params.senderName || "CareTrack Clinic";

  // Mock bypass when running in demo/offline mode
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
      "Accept": "application/json",
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
