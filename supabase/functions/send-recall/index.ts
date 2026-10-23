// send-recall: Bulk campaign dispatcher enforcing consent, 14-day cooldown & audit logging
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getAuthenticatedUser, createServiceClient } from "../_shared/clients.ts";
import { checkRateLimit } from "../_shared/rate_limiter.ts";
import { sendRecallSchema } from "../_shared/schemas.ts";
import { getMessagingProvider } from "../_shared/providers/messaging_provider.ts";
import { maskPhone } from "../_shared/phone.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { safeLog } from "../_shared/logger.ts";

serve(async (req: Request) => {
  const corsRes = handleCors(req);
  if (corsRes) return corsRes;

  try {
    const { user, profile } = await getAuthenticatedUser(req);
    const body = await req.json();
    const input = sendRecallSchema.parse(body);

    // Rate limit: max 3 bulk campaigns per hour per clinic
    const limit = await checkRateLimit(`recall_camp_${profile.clinic_id}`, 3, 3600);
    if (!limit.allowed) {
      return errorResponse("Campaign rate limit reached. Only 3 bulk recall runs allowed per hour.", 429);
    }

    const service = createServiceClient();
    const messaging = getMessagingProvider();

    // 1. Fetch target patients in bulk
    const { data: patients, error: pError } = await service
      .from("patients")
      .select("id, full_name, phone, messaging_consent, language, clinic_id")
      .in("id", input.patientIds)
      .eq("clinic_id", profile.clinic_id);

    if (pError || !patients) {
      return errorResponse("Failed to fetch target patients", 500);
    }

    // 2. Fetch 14-day recent notifications to prevent fatigue
    const fourteenDaysAgo = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString();
    const { data: recentNotifs } = await service
      .from("notifications")
      .select("patient_id")
      .eq("clinic_id", profile.clinic_id)
      .gte("created_at", fourteenDaysAgo);

    const recentlyMessagedSet = new Set((recentNotifs || []).map((n) => n.patient_id));

    // 3. Create campaign record
    const { data: campaign, error: campError } = await service
      .from("recall_campaigns")
      .insert({
        clinic_id: profile.clinic_id,
        created_by: user.id,
        name: input.campaignName,
        template_text: input.templateText,
        target_count: patients.length,
        status: "running",
      })
      .select()
      .single();

    if (campError) {
      return errorResponse("Failed to initialize recall campaign", 500);
    }

    let sentCount = 0;
    let skippedCount = 0;
    let failedCount = 0;

    for (const patient of patients) {
      // Cooldown check
      if (recentlyMessagedSet.has(patient.id)) {
        skippedCount++;
        continue;
      }

      // Consent check
      if (!patient.messaging_consent || !patient.phone) {
        skippedCount++;
        continue;
      }

      try {
        const res = await messaging.sendTemplate(
          patient.phone,
          "recall_reminder",
          patient.language || "en",
          {
            patient_name: patient.full_name,
            custom_message: input.templateText,
          }
        );

        await service.from("notifications").insert({
          clinic_id: profile.clinic_id,
          patient_id: patient.id,
          channel: "whatsapp",
          status: "sent",
          recipient_masked: maskPhone(patient.phone),
          provider_message_id: res.providerMessageId,
        });

        sentCount++;
      } catch (err: any) {
        failedCount++;
        await service.from("notifications").insert({
          clinic_id: profile.clinic_id,
          patient_id: patient.id,
          channel: "whatsapp",
          status: "failed",
          recipient_masked: maskPhone(patient.phone),
          error: err.message,
        });
      }
    }

    // Update campaign final status
    await service
      .from("recall_campaigns")
      .update({
        sent_count: sentCount,
        status: "completed",
      })
      .eq("id", campaign.id);

    await writeAuditLog({
      clinicId: profile.clinic_id,
      userId: user.id,
      action: "EXECUTE_RECALL_CAMPAIGN",
      entity: "recall_campaigns",
      entityId: campaign.id,
    });

    safeLog(`Completed recall campaign '${input.campaignName}': sent=${sentCount}, skipped=${skippedCount}, failed=${failedCount}`);

    return jsonResponse({
      success: true,
      campaignId: campaign.id,
      targetCount: patients.length,
      sentCount,
      skippedCount,
      failedCount,
    });
  } catch (err: any) {
    return errorResponse(err?.message || "Recall dispatch failed", 400);
  }
});
