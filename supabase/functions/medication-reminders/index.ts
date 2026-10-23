// medication-reminders: Generates verified medication adherence schedules and dispatches daily dose notifications
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getAuthenticatedUser, createServiceClient, constantTimeEquals } from "../_shared/clients.ts";
import { generateMedicationScheduleSchema } from "../_shared/schemas.ts";
import { isQuietHours } from "../_shared/date_utils.ts";
import { getMessagingProvider } from "../_shared/providers/messaging_provider.ts";
import { maskPhone } from "../_shared/phone.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { safeLog } from "../_shared/logger.ts";

serve(async (req: Request) => {
  const corsRes = handleCors(req);
  if (corsRes) return corsRes;

  const url = new URL(req.url);
  const mode = url.searchParams.get("mode") || "generate";
  const service = createServiceClient();

  // Mode A: Doctor generates and activates schedule from prescription (Auth required)
  if (mode === "generate") {
    try {
      const { user, profile } = await getAuthenticatedUser(req);
      const body = await req.json();
      const input = generateMedicationScheduleSchema.parse(body);

      const recordsToInsert = input.schedules.map((s) => ({
        clinic_id: profile.clinic_id,
        prescription_id: input.prescriptionId,
        patient_id: input.patientId,
        doctor_id: input.doctorId,
        medicine_name: s.medicineName,
        dosage: s.dosage,
        timing: s.timing,
        start_date: s.startDate,
        end_date: s.endDate,
        is_active: true,
      }));

      const { data: created, error: insertError } = await service
        .from("medication_schedules")
        .insert(recordsToInsert)
        .select();

      if (insertError) {
        return errorResponse("Failed to save medication schedules", 500);
      }

      await writeAuditLog({
        clinicId: profile.clinic_id,
        userId: user.id,
        action: "GENERATE_MEDICATION_SCHEDULE",
        entity: "prescriptions",
        entityId: input.prescriptionId,
      });

      safeLog(`Created ${created.length} medication reminder schedules for patient ${input.patientId}`);

      return jsonResponse({
        success: true,
        count: created.length,
        schedules: created,
      });
    } catch (err: any) {
      return errorResponse(err?.message || "Failed to create medication schedules", 400);
    }
  }

  // Mode B: Scheduled dispatch (Called by pg_cron or background worker with X-Job-Secret)
  if (mode === "dispatch") {
    const jobSecret = req.headers.get("x-job-secret");
    const expected = Deno.env.get("JOB_SECRET");

    if (!expected || !jobSecret || !constantTimeEquals(jobSecret, expected)) {
      return errorResponse("Unauthorized cron job call", 401);
    }

    const todayIso = new Date().toISOString().split("T")[0];

    // Fetch active medication schedules where current date is within start_date and end_date
    const { data: activeSchedules, error: schError } = await service
      .from("medication_schedules")
      .select("id, clinic_id, medicine_name, dosage, timing, patient_id, patients(full_name, phone, messaging_consent, language), clinics(timezone)")
      .eq("is_active", true)
      .lte("start_date", todayIso)
      .gte("end_date", todayIso);

    if (schError || !activeSchedules) {
      return errorResponse("Failed to query active schedules", 500);
    }

    const messaging = getMessagingProvider();
    let sentCount = 0;

    for (const item of activeSchedules) {
      const patient = item.patients as any;
      const clinic = item.clinics as any;
      const tz = clinic?.timezone || "Asia/Kolkata";

      if (!patient || !patient.messaging_consent || !patient.phone) {
        continue;
      }

      // Respect quiet hours
      if (isQuietHours(new Date(), tz)) {
        continue;
      }

      try {
        await messaging.sendTemplate(patient.phone, "medication_reminder", patient.language || "en", {
          patient_name: patient.full_name,
          medicine_name: item.medicine_name,
          dosage: item.dosage,
        });

        sentCount++;
      } catch (err: any) {
        safeLog(`Medication reminder send failed for patient ${patient.phone}: ${err.message}`);
      }
    }

    // Auto-deactivate schedules past end_date
    await service
      .from("medication_schedules")
      .update({ is_active: false })
      .lt("end_date", todayIso);

    return jsonResponse({ success: true, activeCandidates: activeSchedules.length, sentCount });
  }

  return errorResponse("Invalid mode", 400);
});
