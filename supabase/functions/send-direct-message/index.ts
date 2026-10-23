// send-direct-message: Staff sends WhatsApp template or 24h session text to patient with consent
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getAuthenticatedUser, createServiceClient } from "../_shared/clients.ts";
import { sendDirectMessageSchema } from "../_shared/schemas.ts";
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
    const input = sendDirectMessageSchema.parse(body);

    const service = createServiceClient();

    // 1. Fetch patient
    const { data: patient } = await service
      .from("patients")
      .select("id, clinic_id, full_name, phone, messaging_consent, language")
      .eq("id", input.patientId)
      .single();

    if (!patient || patient.clinic_id !== profile.clinic_id) {
      return errorResponse("Patient not found in your clinic", 404);
    }

    if (!patient.messaging_consent) {
      return errorResponse("Cannot send message: patient has opted out of messaging", 403);
    }

    const messaging = getMessagingProvider();
    let providerResult;

    if (input.isTemplate && input.templateName) {
      // Send approved template
      providerResult = await messaging.sendTemplate(
        patient.phone,
        input.templateName,
        patient.language || "en",
        input.templateVariables || {}
      );
    } else {
      // Free-form text: verify within 24h window of last inbound message
      const { data: conv } = await service
        .from("conversations")
        .select("id, last_message_at")
        .eq("clinic_id", profile.clinic_id)
        .eq("patient_id", patient.id)
        .maybeSingle();

      const { data: lastInbound } = await service
        .from("messages")
        .select("created_at")
        .eq("clinic_id", profile.clinic_id)
        .eq("direction", "inbound")
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      const hoursSinceLastInbound = lastInbound
        ? (Date.now() - new Date(lastInbound.created_at).getTime()) / (1000 * 60 * 60)
        : 999;

      if (hoursSinceLastInbound > 24) {
        return errorResponse(
          "The 24-hour customer service window has expired. You must use an approved WhatsApp template to initiate conversation.",
          400
        );
      }

      providerResult = await messaging.sendTextMessage(patient.phone, input.body);
    }

    // Record in notifications and inbox messages
    await service.from("notifications").insert({
      clinic_id: profile.clinic_id,
      patient_id: patient.id,
      channel: input.channel,
      status: "sent",
      recipient_masked: maskPhone(patient.phone),
      provider_message_id: providerResult.providerMessageId,
    });

    // Record in conversations
    let { data: conversation } = await service
      .from("conversations")
      .select("id")
      .eq("clinic_id", profile.clinic_id)
      .eq("patient_id", patient.id)
      .maybeSingle();

    if (!conversation) {
      const { data: newConv } = await service
        .from("conversations")
        .insert({
          clinic_id: profile.clinic_id,
          patient_id: patient.id,
          phone: patient.phone,
          status: "open",
          assigned_to: user.id,
          last_message_at: new Date().toISOString(),
        })
        .select()
        .single();
      conversation = newConv;
    } else {
      await service
        .from("conversations")
        .update({ last_message_at: new Date().toISOString() })
        .eq("id", conversation.id);
    }

    if (conversation) {
      await service.from("messages").insert({
        clinic_id: profile.clinic_id,
        conversation_id: conversation.id,
        sender_type: "staff",
        sender_id: user.id,
        body: input.body,
        direction: "outbound",
        channel: input.channel,
      });
    }

    await writeAuditLog({
      clinicId: profile.clinic_id,
      userId: user.id,
      action: "SEND_DIRECT_MESSAGE",
      entity: "patients",
      entityId: patient.id,
    });

    safeLog(`Staff sent direct message to patient ${patient.id}`);

    return jsonResponse({
      success: true,
      messageId: providerResult.providerMessageId,
    });
  } catch (err: any) {
    return errorResponse(err?.message || "Failed to send message", 400);
  }
});
