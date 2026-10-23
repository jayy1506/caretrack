// get-slots: Public rate-limited endpoint returning available appointment slots
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createServiceClient } from "../_shared/clients.ts";
import { checkRateLimit } from "../_shared/rate_limiter.ts";
import { getSlotsSchema } from "../_shared/schemas.ts";
import { generateSlots } from "../_shared/slot_generator.ts";

serve(async (req: Request) => {
  const corsRes = handleCors(req);
  if (corsRes) return corsRes;

  const clientIp = req.headers.get("x-forwarded-for") || "unknown-ip";
  const limitCheck = await checkRateLimit(`ip_slots_${clientIp}`, 60, 60);
  if (!limitCheck.allowed) {
    return errorResponse("Too many requests. Please wait a moment.", 429);
  }

  try {
    const url = new URL(req.url);
    const doctorId = url.searchParams.get("doctorId");
    const date = url.searchParams.get("date");

    const input = getSlotsSchema.parse({ doctorId, date });
    const service = createServiceClient();

    // 1. Get doctor profile to find clinic_id
    const { data: doctor, error: docError } = await service
      .from("profiles")
      .select("id, clinic_id, role, full_name, active")
      .eq("id", input.doctorId)
      .eq("role", "doctor")
      .single();

    if (docError || !doctor || !doctor.active) {
      return errorResponse("Doctor not found or inactive", 404);
    }

    // 2. Fetch doctor availability
    const { data: availabilities } = await service
      .from("availability")
      .select("*")
      .eq("doctor_id", doctor.id);

    // 3. Fetch clinic holidays
    const { data: holidays } = await service
      .from("clinic_holidays")
      .select("holiday_date")
      .eq("clinic_id", doctor.clinic_id);

    const holidayDates = (holidays || []).map((h) => h.holiday_date);

    // 4. Fetch existing appointments on this date
    const dayStart = `${input.date}T00:00:00.000Z`;
    const dayEnd = `${input.date}T23:59:59.999Z`;

    const { data: existingAppts } = await service
      .from("appointments")
      .select("starts_at, status")
      .eq("doctor_id", doctor.id)
      .neq("status", "cancelled")
      .gte("starts_at", dayStart)
      .lte("starts_at", dayEnd);

    const existingIsoList = (existingAppts || []).map((a) => a.starts_at);

    // 5. Generate slots
    const slots = generateSlots({
      date: input.date,
      availabilities: availabilities || [],
      holidays: holidayDates,
      existingAppointments: existingIsoList,
    });

    return jsonResponse({
      doctorId: doctor.id,
      doctorName: doctor.full_name,
      date: input.date,
      slots,
    });
  } catch (err: any) {
    return errorResponse(err?.message || "Invalid request", 400);
  }
});
