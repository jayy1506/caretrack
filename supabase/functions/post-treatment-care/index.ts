// post-treatment-care: Background dispatcher sending care instructions & pain checks to completed appointment patients
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createServiceClient, constantTimeEquals } from "../_shared/clients.ts";
import { isQuietHours } from "../_shared/date_utils.ts";
import { getMessagingProvider } from "../_shared/providers/messaging_provider.ts";
import { maskPhone } from "../_shared/phone.ts";
import { safeLog, safeError } from "../_shared/logger.ts";

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

  // 1. Claim due post-care appointments atomically via claim_due_post_care()
  const { data: claimedAppointments, error: claimError } = await service.rpc("claim_due_post_care", {
    limit_count: 50,
  });

  if (claimError) {
    safeError("Failed to claim post-care appointments", claimError);
    return errorResponse("Failed to claim post-care appointments", 500);
  }

  if (!claimedAppointments || claimedAppointments.length === 0) {
    return jsonResponse({ message: "No post-treatment care messages due at this time", processed: 0 });
  }

  safeLog(`Processing ${claimedAppointments.length} claimed post-care appointments`);

  const messaging = getMessagingProvider();
  let totalSuccessful = 0;

  for (const appt of claimedAppointments) {
    try {
      // Fetch full appointment details: patient, clinic, doctor
      const { data: apptDetails, error: apptError } = await service
        .from("appointments")
        .select(`
          id,
          clinic_id,
          starts_at,
          patients (id, full_name, phone, language, messaging_consent),
          clinics (id, name, timezone),
          profiles (id, full_name)
        `)
        .eq("id", appt.id)
        .single();

      if (apptError || !apptDetails) {
        safeError(`Failed to fetch details for post-care appointment ${appt.id}`, apptError);
        continue;
      }

      const patient = apptDetails.patients as any;
      const clinic = apptDetails.clinics as any;
      const doctor = apptDetails.profiles as any;
      const clinicTz = clinic?.timezone || "Asia/Kolkata";

      // Verify messaging consent
      if (!patient || !patient.messaging_consent || !patient.phone) {
        safeLog(`Skipping post-care for patient ${patient?.id}: No messaging consent or phone`);
        continue;
      }

      // Respect quiet hours
      if (isQuietHours(new Date(), clinicTz)) {
        safeLog(`Skipping post-care for appointment ${appt.id}: In quiet hours (${clinicTz})`);
        continue;
      }

      const clinicName = clinic?.name || "CareTrack Dental Clinic";
      const doctorName = doctor?.full_name || "your doctor";
      const patientLanguage = patient?.language || "en";

      let providerMessageId: string | null = null;
      let sendSuccess = false;
      let sendError: string | null = null;

      try {
        const result = await messaging.sendTemplate(
          patient.phone,
          "post_treatment_care",
          patientLanguage,
          {
            patient_name: patient.full_name,
            doctor_name: doctorName,
            clinic_name: clinicName,
          }
        );
        providerMessageId = result.providerMessageId;
        sendSuccess = true;
      } catch (err: any) {
        sendError = err?.message || "Failed to dispatch post-care WhatsApp message";
      }

      // Record notification entry
      await service.from("notifications").insert({
        clinic_id: apptDetails.clinic_id,
        appointment_id: appt.id,
        patient_id: patient.id,
        channel: "whatsapp",
        status: sendSuccess ? "sent" : "failed",
        recipient_masked: maskPhone(patient.phone),
        provider_message_id: providerMessageId,
        error: sendError,
      });

      if (sendSuccess) {
        // Mark post_care_sent_at on appointment
        await service
          .from("appointments")
          .update({ post_care_sent_at: new Date().toISOString() })
          .eq("id", appt.id);

        totalSuccessful++;
      }
    } catch (err: any) {
      safeError(`Error processing post-care message for appointment ${appt.id}`, err);
    }
  }

  return jsonResponse({
    success: true,
    processed: claimedAppointments.length,
    sent: totalSuccessful,
  });
});
