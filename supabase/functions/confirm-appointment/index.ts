// confirm-appointment: Public appointment confirmation and rescheduling handler
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createServiceClient, constantTimeEquals } from "../_shared/clients.ts";
import { checkRateLimit } from "../_shared/rate_limiter.ts";
import { confirmAppointmentSchema } from "../_shared/schemas.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { safeLog } from "../_shared/logger.ts";

/**
 * Computes SHA-256 hex digest of a token string.
 */
async function hashToken(token: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(token);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  const corsRes = handleCors(req);
  if (corsRes) return corsRes;

  const clientIp = req.headers.get("x-forwarded-for") || "unknown-ip";

  // Rate limit by IP: 20 requests per minute
  const ipLimit = await checkRateLimit(`ip_confirm_${clientIp}`, 20, 60);
  if (!ipLimit.allowed) {
    return errorResponse("Too many requests. Please try again later.", 429);
  }

  const url = new URL(req.url);

  // 1. GET: Mobile-friendly HTML landing page
  if (req.method === "GET") {
    const rawToken = url.searchParams.get("token") || "";
    if (!rawToken || rawToken.length < 8) {
      return new Response("<h3>Invalid or expired link. Please contact the clinic.</h3>", {
        status: 400,
        headers: { "Content-Type": "text/html; charset=utf-8" },
      });
    }

    const tokenHash = await hashToken(rawToken);
    const service = createServiceClient();

    const { data: appt } = await service
      .from("appointments")
      .select("id, starts_at, status, token_hash, token_expires_at, clinics(name, timezone)")
      .eq("token_hash", tokenHash)
      .maybeSingle();

    if (!appt || !constantTimeEquals(appt.token_hash, tokenHash)) {
      return new Response("<h3>Appointment link not found or already used.</h3>", {
        status: 404,
        headers: { "Content-Type": "text/html; charset=utf-8" },
      });
    }

    if (new Date(appt.token_expires_at) < new Date()) {
      return new Response("<h3>This confirmation link has expired.</h3>", {
        status: 410,
        headers: { "Content-Type": "text/html; charset=utf-8" },
      });
    }

    const formattedTime = new Date(appt.starts_at).toLocaleString("en-IN", {
      dateStyle: "medium",
      timeStyle: "short",
      timeZone: (appt.clinics as any)?.timezone || "Asia/Kolkata",
    });

    const clinicName = (appt.clinics as any)?.name || "CareTrack Clinic";

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Confirm Your Appointment - ${clinicName}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #F3F6FA; margin: 0; padding: 24px; color: #0F2A47; display: flex; justify-content: center; align-items: center; min-height: 90vh; }
    .card { background: #FFFFFF; border-radius: 18px; padding: 32px; box-shadow: 0 8px 30px rgba(15, 42, 71, 0.08); max-width: 440px; width: 100%; text-align: center; }
    h1 { font-size: 22px; color: #0F2A47; margin-bottom: 8px; }
    .subtitle { color: #53657A; font-size: 14px; margin-bottom: 24px; }
    .time-badge { background: #E6F7F5; color: #0F766E; font-weight: 600; padding: 12px 18px; border-radius: 12px; margin-bottom: 24px; font-size: 16px; }
    .btn { display: block; width: 100%; padding: 14px; border-radius: 14px; font-size: 15px; font-weight: 600; cursor: pointer; border: none; margin-bottom: 12px; transition: transform 0.1s ease; }
    .btn-confirm { background: #0F766E; color: #FFFFFF; }
    .btn-reschedule { background: #F3F6FA; color: #0F2A47; }
    .btn:active { transform: scale(0.98); }
    #msg { margin-top: 16px; font-size: 14px; font-weight: 500; }
  </style>
</head>
<body>
  <div class="card">
    <h1>${clinicName}</h1>
    <p class="subtitle">Appointment Confirmation</p>
    <div class="time-badge">${formattedTime}</div>
    <div id="actions">
      <button class="btn btn-confirm" onclick="submitAction('confirm')">✓ Confirm Appointment</button>
      <button class="btn btn-reschedule" onclick="submitAction('reschedule')">↻ Request Reschedule</button>
    </div>
    <div id="msg"></div>
  </div>
  <script>
    async function submitAction(action) {
      const msg = document.getElementById('msg');
      const actions = document.getElementById('actions');
      msg.innerText = "Processing...";
      try {
        const res = await fetch(window.location.pathname, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ token: "${rawToken}", action: action })
        });
        const data = await res.json();
        if (res.ok) {
          actions.style.display = 'none';
          msg.innerHTML = '<span style="color:#0B6B4A;font-weight:600;">' + data.message + '</span>';
        } else {
          msg.innerHTML = '<span style="color:#A12626;">' + (data.error || 'Failed to update') + '</span>';
        }
      } catch (e) {
        msg.innerHTML = '<span style="color:#A12626;">Network error. Please try again.</span>';
      }
    }
  </script>
</body>
</html>`;
    return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8" } });
  }

  // 2. POST: Process confirm or reschedule
  if (req.method === "POST") {
    const body = await req.json();
    const input = confirmAppointmentSchema.parse(body);

    const tokenLimit = await checkRateLimit(`token_limit_${input.token.slice(0, 10)}`, 5, 60);
    if (!tokenLimit.allowed) {
      return errorResponse("Too many attempts on this link.", 429);
    }

    const tokenHash = await hashToken(input.token);
    const service = createServiceClient();

    const { data: appt, error: findError } = await service
      .from("appointments")
      .select("id, clinic_id, patient_id, doctor_id, status, token_hash, token_expires_at")
      .eq("token_hash", tokenHash)
      .maybeSingle();

    if (findError || !appt || !constantTimeEquals(appt.token_hash, tokenHash)) {
      return errorResponse("Invalid or already utilized appointment link", 400);
    }

    if (new Date(appt.token_expires_at) < new Date()) {
      return errorResponse("Appointment link has expired", 410);
    }

    const newStatus = input.action === "confirm" ? "confirmed" : "reschedule_requested";

    // Expire the token to enforce single-use
    const { error: updateError } = await service
      .from("appointments")
      .update({
        status: newStatus,
        token_expires_at: new Date().toISOString(), // single-use expiry
      })
      .eq("id", appt.id);

    if (updateError) {
      return errorResponse("Failed to update appointment status", 500);
    }

    // Write audit log
    await writeAuditLog({
      clinicId: appt.clinic_id,
      action: input.action === "confirm" ? "PATIENT_CONFIRMED_APPOINTMENT" : "PATIENT_REQUESTED_RESCHEDULE",
      entity: "appointments",
      entityId: appt.id,
    });

    safeLog(`Appointment ${appt.id} status updated to ${newStatus}`);

    return jsonResponse({
      success: true,
      status: newStatus,
      message:
        input.action === "confirm"
          ? "Thank you! Your appointment is confirmed."
          : "Reschedule request received. Our clinic staff will reach out to schedule your new time.",
    });
  }

  return errorResponse("Method not allowed", 405);
});
