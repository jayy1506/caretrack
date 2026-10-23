// send-notifications: Service-role background reminder dispatcher with multi-channel resilience
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createServiceClient, constantTimeEquals } from "../_shared/clients.ts";
import { isQuietHours } from "../_shared/date_utils.ts";
import { getMessagingProvider } from "../_shared/providers/messaging_provider.ts";
import { sendEmail } from "../_shared/providers/email_provider.ts";
import { maskPhone } from "../_shared/phone.ts";
import { safeLog, safeError } from "../_shared/logger.ts";

/**
 * Retries an async action up to `maxRetries` times with exponential backoff for 5xx/network errors.
 */
async function retryWithBackoff<T>(fn: () => Promise<T>, maxRetries = 2): Promise<T> {
  let attempt = 0;
  while (attempt <= maxRetries) {
    try {
      return await fn();
    } catch (err: any) {
      attempt++;
      const isNetworkOr5xx =
        !err.message ||
        err.message.includes("5") ||
        err.message.includes("fetch") ||
        err.message.includes("network");

      if (attempt > maxRetries || !isNetworkOr5xx) {
        throw err;
      }
      const backoffMs = Math.pow(2, attempt) * 200;
      await new Promise((resolve) => setTimeout(resolve, backoffMs));
    }
  }
  throw new Error("Exceeded max retries");
}

serve(async (req: Request) => {
  const corsRes = handleCors(req);
  if (corsRes) return corsRes;

  const jobSecretHeader = req.headers.get("x-job-secret");
  const authHeader = req.headers.get("authorization");
  const expectedSecret = Deno.env.get("JOB_SECRET");

  // Verify authentication: either matching X-Job-Secret or Service Role JWT
  const isSecretValid =
    expectedSecret && jobSecretHeader && constantTimeEquals(jobSecretHeader, expectedSecret);
  const isServiceRole =
    authHeader && authHeader.includes(Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "__none__");

  if (!isSecretValid && !isServiceRole) {
    return errorResponse("Unauthorized: Missing or invalid secret/credentials", 401);
  }

  const service = createServiceClient();

  // 1. Claim due reminders atomically via the claim_due_reminders() function
  const { data: claimedAppointments, error: claimError } = await service.rpc("claim_due_reminders", {
    limit_count: 50,
  });

  if (claimError) {
    safeError("Failed to claim reminders", claimError);
    return errorResponse("Failed to claim reminders", 500);
  }

  if (!claimedAppointments || claimedAppointments.length === 0) {
    return jsonResponse({ message: "No reminders due at this time", processed: 0 });
  }

  safeLog(`Processing ${claimedAppointments.length} claimed reminders`);

  const messaging = getMessagingProvider();
  const baseAppUrl = Deno.env.get("BASE_APP_URL") || "https://caretrack.local";
  let totalSuccessfulReminders = 0;

  for (const appt of claimedAppointments) {
    // Fetch patient, clinic, doctor details
    const { data: patient } = await service
      .from("patients")
      .select("id, full_name, phone, email, messaging_consent, language")
      .eq("id", appt.patient_id)
      .single();

    const { data: clinic } = await service
      .from("clinics")
      .select("id, name, timezone")
      .eq("id", appt.clinic_id)
      .single();

    if (!patient || !clinic) continue;

    const tz = clinic.timezone || "Asia/Kolkata";
    const quiet = isQuietHours(new Date(), tz);

    // If quiet hours and WhatsApp/SMS are active, defer reminder
    if (quiet) {
      safeLog(`Deferring reminder for appointment ${appt.id} due to quiet hours in ${tz}`);
      continue;
    }

    const appointmentTimeFormatted = new Date(appt.starts_at).toLocaleString("en-IN", {
      dateStyle: "medium",
      timeStyle: "short",
      timeZone: tz,
    });

    const confirmUrl = `${baseAppUrl}/confirm?token=${appt.token_hash?.slice(0, 32)}`;

    // Channel 1: WhatsApp
    const sendWhatsApp = async () => {
      if (!patient.messaging_consent || !patient.phone) {
        await service.from("notifications").insert({
          clinic_id: clinic.id,
          appointment_id: appt.id,
          patient_id: patient.id,
          channel: "whatsapp",
          status: "skipped",
          recipient_masked: maskPhone(patient.phone || ""),
          error: "Patient consent not granted or missing phone",
        });
        return { channel: "whatsapp", success: false, skipped: true };
      }

      try {
        const result = await retryWithBackoff(() =>
          messaging.sendTemplate(patient.phone, "appointment_reminder", patient.language || "en", {
            patient_name: patient.full_name,
            clinic_name: clinic.name,
            starts_at: appointmentTimeFormatted,
            confirm_link: confirmUrl,
          })
        );

        await service.from("notifications").insert({
          clinic_id: clinic.id,
          appointment_id: appt.id,
          patient_id: patient.id,
          channel: "whatsapp",
          status: "sent",
          recipient_masked: maskPhone(patient.phone),
          provider_message_id: result.providerMessageId,
        });

        return { channel: "whatsapp", success: true };
      } catch (err: any) {
        await service.from("notifications").insert({
          clinic_id: clinic.id,
          appointment_id: appt.id,
          patient_id: patient.id,
          channel: "whatsapp",
          status: "failed",
          recipient_masked: maskPhone(patient.phone),
          error: err.message || "Failed to send WhatsApp message",
        });
        return { channel: "whatsapp", success: false };
      }
    };

    // Channel 2: Email (Brevo HTTP API)
    const sendEmailChannel = async () => {
      if (!patient.email) {
        return { channel: "email", success: false, skipped: true };
      }

      try {
        const emailContent = `
          <div style="font-family:sans-serif;max-width:500px;margin:auto;padding:20px;border-radius:12px;background:#f9fafb;">
            <h2 style="color:#0F2A47;">${clinic.name}</h2>
            <p>Hello ${patient.full_name},</p>
            <p>This is a reminder for your dental appointment scheduled on:</p>
            <p style="font-size:16px;font-weight:bold;color:#0F766E;">${appointmentTimeFormatted}</p>
            <a href="${confirmUrl}" style="display:inline-block;padding:12px 20px;background:#0F766E;color:#fff;text-decoration:none;border-radius:8px;">Manage / Confirm Appointment</a>
          </div>
        `;

        const result = await retryWithBackoff(() =>
          sendEmail({
            toEmail: patient.email,
            toName: patient.full_name,
            subject: `Appointment Reminder: ${clinic.name}`,
            htmlContent: emailContent,
          })
        );

        await service.from("notifications").insert({
          clinic_id: clinic.id,
          appointment_id: appt.id,
          patient_id: patient.id,
          channel: "email",
          status: "sent",
          recipient_masked: "[REDACTED_EMAIL]",
          provider_message_id: result.messageId,
        });

        return { channel: "email", success: true };
      } catch (err: any) {
        await service.from("notifications").insert({
          clinic_id: clinic.id,
          appointment_id: appt.id,
          patient_id: patient.id,
          channel: "email",
          status: "failed",
          recipient_masked: "[REDACTED_EMAIL]",
          error: err.message || "Failed to send email",
        });
        return { channel: "email", success: false };
      }
    };

    // Parallel execution: one failure does not block the other
    const results = await Promise.allSettled([sendWhatsApp(), sendEmailChannel()]);

    const anySuccess = results.some(
      (r) => r.status === "fulfilled" && (r.value as any)?.success === true
    );

    // Mark reminder_sent_at ONLY after at least one channel succeeds
    if (anySuccess) {
      totalSuccessfulReminders++;
      await service
        .from("appointments")
        .update({ reminder_sent_at: new Date().toISOString() })
        .eq("id", appt.id);
    }
  }

  return jsonResponse({
    success: true,
    claimed: claimedAppointments.length,
    sentReminders: totalSuccessfulReminders,
  });
});
