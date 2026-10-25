// retry-notification: Staff retries a failed notification with ownership check & rate limit
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getAuthenticatedUser, createServiceClient } from "../_shared/clients.ts";
import { checkRateLimit } from "../_shared/rate_limiter.ts";
import { retryNotificationSchema } from "../_shared/schemas.ts";
import { getMessagingProvider } from "../_shared/providers/messaging_provider.ts";
import { sendEmail } from "../_shared/providers/email_provider.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { safeLog } from "../_shared/logger.ts";

serve(async (req: Request) => {
  const corsRes = handleCors(req);
  if (corsRes) return corsRes;

  try {
    const { user, profile } = await getAuthenticatedUser(req);
    const body = await req.json();
    const input = retryNotificationSchema.parse(body);

    // Rate limit: max 10 retries per minute per staff member
    const limit = await checkRateLimit(`retry_notif_${user.id}`, 10, 60);
    if (!limit.allowed) {
      return errorResponse("Retry rate limit reached. Please wait a moment.", 429);
    }

    const service = createServiceClient();

    // Fetch notification record
    const { data: notif, error: notifError } = await service
      .from("notifications")
      .select("id, clinic_id, appointment_id, patient_id, channel, status, appointments(starts_at), patients(id, full_name, phone, email, messaging_consent, language)")
      .eq("id", input.notificationId)
      .single();

    if (notifError || !notif || notif.clinic_id !== profile.clinic_id) {
      return errorResponse("Notification not found in your clinic", 404);
    }

    const patient = notif.patients as any;
    if (!patient) return errorResponse("Associated patient not found", 404);

    let resendSuccess = false;
    let providerId: string | null = null;
    let errorMessage: string | null = null;

    if (notif.channel === "whatsapp") {
      if (!patient.messaging_consent) {
        return errorResponse("Patient has opted out of messaging", 403);
      }
      try {
        const messaging = getMessagingProvider();
        const res = await messaging.sendTemplate(
          patient.phone,
          "appointment_reminder",
          patient.language || "en",
          {
            patient_name: patient.full_name,
            starts_at: (notif.appointments as any)?.starts_at
              ? new Date((notif.appointments as any).starts_at).toLocaleString()
              : "Upcoming",
          }
        );
        resendSuccess = true;
        providerId = res.providerMessageId;
      } catch (e: any) {
        errorMessage = e.message;
      }
    } else if (notif.channel === "sms") {
      if (!patient.messaging_consent) {
        return errorResponse("Patient has opted out of messaging", 403);
      }
      try {
        const messaging = getMessagingProvider("twilio_sms");
        const res = await messaging.sendTemplate(
          patient.phone,
          "appointment_reminder",
          patient.language || "en",
          {
            patient_name: patient.full_name,
            starts_at: (notif.appointments as any)?.starts_at
              ? new Date((notif.appointments as any).starts_at).toLocaleString()
              : "Upcoming",
          }
        );
        resendSuccess = true;
        providerId = res.providerMessageId;
      } catch (e: any) {
        errorMessage = e.message;
      }
    } else if (notif.channel === "email") {
      if (!patient.email) return errorResponse("Patient does not have an email address", 400);
      try {
        const res = await sendEmail({
          toEmail: patient.email,
          toName: patient.full_name,
          subject: "Appointment Update",
          htmlContent: `<p>Hello ${patient.full_name}, your clinic has sent you an update regarding your appointment.</p>`,
        });
        resendSuccess = true;
        providerId = res.messageId;
      } catch (e: any) {
        errorMessage = e.message;
      }
    }

    // Update notification status
    await service
      .from("notifications")
      .update({
        status: resendSuccess ? "sent" : "failed",
        provider_message_id: providerId,
        error: errorMessage,
      })
      .eq("id", notif.id);

    await writeAuditLog({
      clinicId: profile.clinic_id,
      userId: user.id,
      action: "RETRY_NOTIFICATION",
      entity: "notifications",
      entityId: notif.id,
    });

    safeLog(`Staff retried notification ${notif.id}: success=${resendSuccess}`);

    return jsonResponse({
      success: resendSuccess,
      providerMessageId: providerId,
      error: errorMessage,
    });
  } catch (err: any) {
    return errorResponse(err?.message || "Failed to retry notification", 400);
  }
});
