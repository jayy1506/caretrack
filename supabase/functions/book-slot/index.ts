// book-slot: Public rate-limited appointment booking with unique constraint conflict handling
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createServiceClient } from "../_shared/clients.ts";
import { checkRateLimit } from "../_shared/rate_limiter.ts";
import { bookSlotSchema } from "../_shared/schemas.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { safeLog } from "../_shared/logger.ts";

async function generateSecureToken(): Promise<{ rawToken: string; tokenHash: string }> {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  const rawToken = Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  const encoder = new TextEncoder();
  const data = encoder.encode(rawToken);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const tokenHash = Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return { rawToken, tokenHash };
}

serve(async (req: Request) => {
  const corsRes = handleCors(req);
  if (corsRes) return corsRes;

  const clientIp = req.headers.get("x-forwarded-for") || "unknown-ip";
  const limit = await checkRateLimit(`ip_book_${clientIp}`, 10, 60);
  if (!limit.allowed) {
    return errorResponse("Too many booking requests. Please wait a minute.", 429);
  }

  try {
    const body = await req.json();
    const input = bookSlotSchema.parse(body);

    const service = createServiceClient();

    // 1. Verify patient & doctor
    const { data: patient } = await service
      .from("patients")
      .select("id, clinic_id, full_name")
      .eq("id", input.patientId)
      .single();

    if (!patient) return errorResponse("Patient not found", 404);

    const { data: doctor } = await service
      .from("profiles")
      .select("id, clinic_id, role, full_name, active")
      .eq("id", input.doctorId)
      .eq("role", "doctor")
      .single();

    if (!doctor || !doctor.active || doctor.clinic_id !== patient.clinic_id) {
      return errorResponse("Doctor not available for this clinic", 400);
    }

    // 2. Generate secure single-use confirmation token
    const { rawToken, tokenHash } = await generateSecureToken();
    const tokenExpiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

    // 3. Insert appointment inside transaction / relying on unique (doctor_id, starts_at)
    const { data: appointment, error: insertError } = await service
      .from("appointments")
      .insert({
        clinic_id: patient.clinic_id,
        patient_id: patient.id,
        doctor_id: doctor.id,
        starts_at: input.startsAt,
        status: "pending",
        token_hash: tokenHash,
        token_expires_at: tokenExpiresAt,
      })
      .select()
      .single();

    if (insertError) {
      if (insertError.code === "23505" || insertError.message?.includes("unique")) {
        return errorResponse(
          "This time slot has already been booked. Please choose another available slot.",
          409
        );
      }
      return errorResponse("Failed to schedule appointment. Please try again.", 500);
    }

    await writeAuditLog({
      clinicId: patient.clinic_id,
      action: "BOOK_APPOINTMENT_SLOT",
      entity: "appointments",
      entityId: appointment.id,
    });

    safeLog(`Booked appointment ${appointment.id} for patient ${patient.id}`);

    return jsonResponse({
      success: true,
      appointment: {
        id: appointment.id,
        startsAt: appointment.starts_at,
        status: appointment.status,
      },
      confirmationToken: rawToken, // Returned to client for immediate redirect if needed
    });
  } catch (err: any) {
    return errorResponse(err?.message || "Invalid booking payload", 400);
  }
});
