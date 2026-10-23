// whatsapp-webhook: Public Meta Webhook with cryptographic HMAC verification, multi-lingual triage & inbox routing
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createServiceClient, constantTimeEquals } from "../_shared/clients.ts";
import { normalizePhone, maskPhone } from "../_shared/phone.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { safeLog, safeError } from "../_shared/logger.ts";

/**
 * Verifies Meta's X-Hub-Signature-256 HMAC SHA-256 signature.
 */
async function verifySignature(signatureHeader: string | null, rawBody: string, appSecret: string): Promise<boolean> {
  if (!signatureHeader || !signatureHeader.startsWith("sha256=")) return false;
  const signatureHex = signatureHeader.replace("sha256=", "");

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(appSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const mac = await crypto.subtle.sign("HMAC", key, encoder.encode(rawBody));
  const expectedHex = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return constantTimeEquals(signatureHex, expectedHex);
}

// Multilingual emergency keywords indicating urgent staff attention required
const URGENT_KEYWORDS = [
  "pain", "ache", "hurt", "swelling", "bleed", "bleeding", "blood", "fever", "emergency", "infection",
  // Hindi
  "दर्द", "सूजन", "खून", "रक्त", "बुखार", "तकलीफ", "आपातकाल",
  // Marathi
  "दुखणे", "सूज", "ताप", "रक्तस्त्राव", "वेदना"
];

function isUrgentMessage(text: string): boolean {
  const lower = text.toLowerCase();
  return URGENT_KEYWORDS.some((kw) => lower.includes(kw.toLowerCase()));
}

serve(async (req: Request) => {
  const corsRes = handleCors(req);
  if (corsRes) return corsRes;

  const url = new URL(req.url);

  // 1. GET: Webhook verification handshake from Meta
  if (req.method === "GET") {
    const mode = url.searchParams.get("hub.mode");
    const token = url.searchParams.get("hub.verify_token");
    const challenge = url.searchParams.get("hub.challenge");

    const expectedToken = Deno.env.get("WHATSAPP_VERIFY_TOKEN") || "caretrack_webhook_token";

    if (mode === "subscribe" && token && constantTimeEquals(token, expectedToken)) {
      safeLog("WhatsApp webhook verification handshake successful");
      return new Response(challenge, { status: 200 });
    }
    return new Response("Forbidden", { status: 403 });
  }

  // 2. POST: Inbound WhatsApp messages & status callbacks
  if (req.method === "POST") {
    const rawBody = await req.text();
    const appSecret = Deno.env.get("WHATSAPP_APP_SECRET");

    // Cryptographic signature verification if secret is configured
    if (appSecret && appSecret !== "mock-app-secret") {
      const signature = req.headers.get("x-hub-signature-256");
      const isValid = await verifySignature(signature, rawBody, appSecret);
      if (!isValid) {
        safeError("Invalid WhatsApp X-Hub-Signature-256");
        return errorResponse("Invalid signature", 401);
      }
    }

    let payload: any;
    try {
      payload = JSON.parse(rawBody);
    } catch {
      return errorResponse("Invalid JSON payload", 400);
    }

    const entry = payload?.entry?.[0]?.changes?.[0]?.value;
    const message = entry?.messages?.[0];

    // Status receipt (sent, delivered, read)
    if (!message) {
      return jsonResponse({ status: "acknowledged" });
    }

    const fromRaw = message.from; // e.g. "919876543210"
    const textBody = (message.text?.body || message.button?.text || "").trim();
    const normalizedSenderPhone = normalizePhone(fromRaw);

    const service = createServiceClient();

    // Look up patient by normalized phone
    const { data: patient } = await service
      .from("patients")
      .select("id, clinic_id, full_name, messaging_consent, doctor_id")
      .eq("phone", normalizedSenderPhone)
      .maybeSingle();

    if (!patient) {
      safeLog(`Message from unregistered number: ${maskPhone(normalizedSenderPhone)}`);
      return jsonResponse({ status: "unregistered_sender" });
    }

    const textUpper = textBody.toUpperCase();

    // Check for STOP / Opt-Out (English, Hindi, Marathi)
    if (["STOP", "UNSUBSCRIBE", "थांबवा", "बंद"].includes(textUpper)) {
      await service
        .from("patients")
        .update({ messaging_consent: false })
        .eq("id", patient.id);

      await service.from("consents").insert({
        clinic_id: patient.clinic_id,
        patient_id: patient.id,
        type: "messaging",
        granted: false,
        method: "whatsapp_opt_out",
        notes: `Patient texted STOP: ${textBody}`,
      });

      await writeAuditLog({
        clinicId: patient.clinic_id,
        action: "PATIENT_OPT_OUT_MESSAGING",
        entity: "patients",
        entityId: patient.id,
      });

      safeLog(`Patient ${patient.id} opted out of messaging via WhatsApp`);
      return jsonResponse({ status: "opted_out" });
    }

    // Check for "1" / Confirm
    if (["1", "CONFIRM", "YES", "हाँ", "हो"].includes(textUpper)) {
      // Find latest pending appointment
      const { data: appt } = await service
        .from("appointments")
        .select("id")
        .eq("patient_id", patient.id)
        .eq("status", "pending")
        .order("starts_at", { ascending: true })
        .limit(1)
        .maybeSingle();

      if (appt) {
        await service
          .from("appointments")
          .update({ status: "confirmed" })
          .eq("id", appt.id);

        await writeAuditLog({
          clinicId: patient.clinic_id,
          action: "PATIENT_CONFIRMED_VIA_WHATSAPP",
          entity: "appointments",
          entityId: appt.id,
        });

        safeLog(`Appointment ${appt.id} confirmed via WhatsApp reply`);
      }
      return jsonResponse({ status: "confirmed" });
    }

    // Check for "2" / Reschedule
    if (["2", "RESCHEDULE", "बदला", "CHANGE"].includes(textUpper)) {
      const { data: appt } = await service
        .from("appointments")
        .select("id")
        .eq("patient_id", patient.id)
        .in("status", ["pending", "confirmed"])
        .order("starts_at", { ascending: true })
        .limit(1)
        .maybeSingle();

      if (appt) {
        await service
          .from("appointments")
          .update({ status: "reschedule_requested" })
          .eq("id", appt.id);

        await writeAuditLog({
          clinicId: patient.clinic_id,
          action: "PATIENT_RESCHEDULE_VIA_WHATSAPP",
          entity: "appointments",
          entityId: appt.id,
        });

        safeLog(`Appointment ${appt.id} reschedule requested via WhatsApp reply`);
      }
      return jsonResponse({ status: "reschedule_requested" });
    }

    // Triage urgent clinical symptoms (Pain, Fever, Bleeding)
    const urgent = isUrgentMessage(textBody);

    // Route other messages to Conversations & Messages (Inbox)
    // 1. Get or create active conversation
    let { data: conv } = await service
      .from("conversations")
      .select("id, is_urgent")
      .eq("clinic_id", patient.clinic_id)
      .eq("patient_id", patient.id)
      .eq("status", "open")
      .maybeSingle();

    if (!conv) {
      const { data: newConv } = await service
        .from("conversations")
        .insert({
          clinic_id: patient.clinic_id,
          patient_id: patient.id,
          phone: normalizedSenderPhone,
          status: "open",
          is_urgent: urgent,
          assigned_to: patient.doctor_id,
          last_message_at: new Date().toISOString(),
        })
        .select()
        .single();
      conv = newConv;
    } else if (urgent && !conv.is_urgent) {
      await service
        .from("conversations")
        .update({ is_urgent: true, last_message_at: new Date().toISOString() })
        .eq("id", conv.id);
    } else {
      await service
        .from("conversations")
        .update({ last_message_at: new Date().toISOString() })
        .eq("id", conv.id);
    }

    // 2. Insert incoming message
    if (conv) {
      await service.from("messages").insert({
        clinic_id: patient.clinic_id,
        conversation_id: conv.id,
        sender_type: "patient",
        body: textBody,
        direction: "inbound",
        channel: "whatsapp",
        is_urgent: urgent,
      });

      safeLog(`Inbox message received from ${maskPhone(normalizedSenderPhone)}, urgent: ${urgent}`);
    }

    return jsonResponse({ status: "received", urgent });
  }

  return errorResponse("Method not allowed", 405);
});
