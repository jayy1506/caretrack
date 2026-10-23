// patient-data-tools: DPDP/GDPR Data Subject Tools (Export & Right-to-Erasure) - Owner Only
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getAuthenticatedUser, createServiceClient } from "../_shared/clients.ts";
import { exportPatientDataSchema, erasePatientDataSchema } from "../_shared/schemas.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { safeLog } from "../_shared/logger.ts";

serve(async (req: Request) => {
  const corsRes = handleCors(req);
  if (corsRes) return corsRes;

  try {
    const { user, profile } = await getAuthenticatedUser(req);

    // Enforce owner role strictly
    if (profile.role !== "owner") {
      return errorResponse("Forbidden: Only clinic owners can execute data subject export or erasure", 403);
    }

    const body = await req.json();
    const action = body.action || "export";
    const service = createServiceClient();

    // 1. Data Subject Access Request (Export)
    if (action === "export") {
      const input = exportPatientDataSchema.parse(body);

      // Verify patient belongs to clinic
      const { data: patient, error: pErr } = await service
        .from("patients")
        .select("*")
        .eq("id", input.patientId)
        .eq("clinic_id", profile.clinic_id)
        .single();

      if (pErr || !patient) {
        return errorResponse("Patient record not found in your clinic", 404);
      }

      // Collect all related records
      const [prescriptions, appointments, plans, messages, notifications, feedback, consents] =
        await Promise.all([
          service.from("prescriptions").select("*").eq("patient_id", patient.id),
          service.from("appointments").select("*").eq("patient_id", patient.id),
          service.from("treatment_plans").select("*, plan_stages(*)").eq("patient_id", patient.id),
          service.from("conversations").select("*, messages(*)").eq("patient_id", patient.id),
          service.from("notifications").select("*").eq("patient_id", patient.id),
          service.from("feedback").select("*").eq("patient_id", patient.id),
          service.from("consents").select("*").eq("patient_id", patient.id),
        ]);

      const bundle = {
        exportedAt: new Date().toISOString(),
        clinicId: profile.clinic_id,
        patientProfile: patient,
        prescriptions: prescriptions.data || [],
        appointments: appointments.data || [],
        treatmentPlans: plans.data || [],
        conversations: messages.data || [],
        notifications: notifications.data || [],
        feedback: feedback.data || [],
        consents: consents.data || [],
      };

      await writeAuditLog({
        clinicId: profile.clinic_id,
        userId: user.id,
        action: "EXPORT_PATIENT_DATA",
        entity: "patients",
        entityId: patient.id,
      });

      safeLog(`Exported complete data archive for patient ${patient.id}`);

      return jsonResponse({ success: true, data: bundle });
    }

    // 2. Right to Erasure / Deletion
    if (action === "erase") {
      const input = erasePatientDataSchema.parse(body);

      const { data: patient } = await service
        .from("patients")
        .select("id, clinic_id, doctor_id")
        .eq("id", input.patientId)
        .eq("clinic_id", profile.clinic_id)
        .single();

      if (!patient) {
        return errorResponse("Patient not found in your clinic", 404);
      }

      // Delete storage files if any in private bucket under {clinic_id}/{doctor_id}/
      try {
        const { data: files } = await service.storage
          .from("prescriptions")
          .list(`${profile.clinic_id}/${patient.doctor_id}`);

        if (files && files.length > 0) {
          const filePaths = files.map(
            (f) => `${profile.clinic_id}/${patient.doctor_id}/${f.name}`
          );
          await service.storage.from("prescriptions").remove(filePaths);
        }
      } catch (err: any) {
        safeLog(`Notice: Storage cleanup skipped or empty: ${err.message}`);
      }

      // Delete all related records in transactional order or cascading
      // Conversations, appointments, prescriptions cascade automatically from foreign keys on patients(id)
      await service.from("notifications").delete().eq("patient_id", patient.id);
      await service.from("feedback").delete().eq("patient_id", patient.id);
      await service.from("consents").delete().eq("patient_id", patient.id);
      await service.from("patients").delete().eq("id", patient.id);

      await writeAuditLog({
        clinicId: profile.clinic_id,
        userId: user.id,
        action: "ERASE_PATIENT_DATA",
        entity: "patients",
        entityId: patient.id,
      });

      safeLog(`Permanently erased all data for patient ${patient.id}`);

      return jsonResponse({
        success: true,
        message: "Patient record, prescriptions, appointments, messages, and storage assets permanently erased.",
      });
    }

    return errorResponse("Unknown action", 400);
  } catch (err: any) {
    return errorResponse(err?.message || "Data subject operation failed", 400);
  }
});
