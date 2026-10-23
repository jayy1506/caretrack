// treatment-plans: Orchestrates multi-stage dental plans, month-end date math, and appointment staging
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getAuthenticatedUser, createServiceClient } from "../_shared/clients.ts";
import { calculateNextStageDate } from "../_shared/date_utils.ts";
import {
  createPlanFromTemplateSchema,
  completeStageSchema,
  stageActionSchema,
  planActionSchema,
} from "../_shared/schemas.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { safeLog } from "../_shared/logger.ts";

serve(async (req: Request) => {
  const corsRes = handleCors(req);
  if (corsRes) return corsRes;

  try {
    const { user, profile } = await getAuthenticatedUser(req);
    const body = await req.json();
    const action = body.action || "create_from_template";
    const service = createServiceClient();

    // 1. Create plan from template
    if (action === "create_from_template") {
      const input = createPlanFromTemplateSchema.parse(body);

      // Verify template
      const { data: template } = await service
        .from("treatment_plan_templates")
        .select("id, title, stages")
        .eq("id", input.templateId)
        .eq("clinic_id", profile.clinic_id)
        .single();

      if (!template) return errorResponse("Treatment plan template not found", 404);

      // Create treatment plan
      const planTitle = input.customTitle || template.title;
      const { data: newPlan, error: planError } = await service
        .from("treatment_plans")
        .insert({
          clinic_id: profile.clinic_id,
          patient_id: input.patientId,
          doctor_id: input.doctorId,
          template_id: template.id,
          title: planTitle,
          status: "active",
        })
        .select()
        .single();

      if (planError || !newPlan) {
        return errorResponse("Failed to create treatment plan", 500);
      }

      // Populate stages
      const stagesData = (template.stages as any[]).map((stg, idx) => ({
        clinic_id: profile.clinic_id,
        plan_id: newPlan.id,
        stage_order: stg.order || idx + 1,
        name: stg.name,
        interval_days_from_previous: stg.interval_days || 0,
        status: idx === 0 ? "pending" : "pending",
      }));

      await service.from("plan_stages").insert(stagesData);

      await writeAuditLog({
        clinicId: profile.clinic_id,
        userId: user.id,
        action: "CREATE_TREATMENT_PLAN",
        entity: "treatment_plans",
        entityId: newPlan.id,
      });

      safeLog(`Created treatment plan ${newPlan.id} for patient ${input.patientId}`);

      return jsonResponse({
        success: true,
        planId: newPlan.id,
        title: newPlan.title,
        stagesCount: stagesData.length,
      });
    }

    // 2. Complete current stage & propose next appointment date
    if (action === "complete_stage") {
      const input = completeStageSchema.parse(body);

      const { data: currentStage } = await service
        .from("plan_stages")
        .select("id, plan_id, stage_order, name, status, plan_id, treatment_plans(id, clinic_id, patient_id, doctor_id)")
        .eq("id", input.stageId)
        .eq("clinic_id", profile.clinic_id)
        .single();

      if (!currentStage) return errorResponse("Stage record not found", 404);

      const parentPlan = currentStage.treatment_plans as any;

      // Mark current stage completed
      await service
        .from("plan_stages")
        .update({
          status: "completed",
          completed_at: new Date().toISOString(),
          notes: input.clinicalNotes,
        })
        .eq("id", currentStage.id);

      // Find next sequential stage
      const { data: nextStage } = await service
        .from("plan_stages")
        .select("id, stage_order, name, interval_days_from_previous")
        .eq("plan_id", currentStage.plan_id)
        .gt("stage_order", currentStage.stage_order)
        .order("stage_order", { ascending: true })
        .limit(1)
        .maybeSingle();

      let proposedDate: string | null = null;
      let nextAppointmentId: string | null = null;

      if (nextStage) {
        // Fetch clinic holidays to safely skip
        const { data: holidays } = await service
          .from("clinic_holidays")
          .select("holiday_date")
          .eq("clinic_id", profile.clinic_id);

        const holidayDates = (holidays || []).map((h) => h.holiday_date);

        // Safe date math skipping Sundays and clinic holidays
        const targetDate = calculateNextStageDate(
          new Date(),
          nextStage.interval_days_from_previous || 7,
          holidayDates,
          true // Skip Sundays
        );

        // Default appointment time: 10:00 AM on proposed date
        targetDate.setUTCHours(10, 0, 0, 0);
        proposedDate = targetDate.toISOString();

        if (input.confirmNextAppointment) {
          // Create next appointment in pending state
          const { data: newAppt } = await service
            .from("appointments")
            .insert({
              clinic_id: profile.clinic_id,
              patient_id: parentPlan.patient_id,
              doctor_id: parentPlan.doctor_id,
              starts_at: proposedDate,
              status: "pending",
            })
            .select()
            .single();

          if (newAppt) {
            nextAppointmentId = newAppt.id;
            // Link appointment to stage
            await service
              .from("plan_stages")
              .update({
                appointment_id: newAppt.id,
                status: "scheduled",
              })
              .eq("id", nextStage.id);
          }
        }
      } else {
        // All stages completed -> mark plan completed
        await service
          .from("treatment_plans")
          .update({ status: "completed", updated_at: new Date().toISOString() })
          .eq("id", currentStage.plan_id);
      }

      await writeAuditLog({
        clinicId: profile.clinic_id,
        userId: user.id,
        action: "COMPLETE_TREATMENT_STAGE",
        entity: "plan_stages",
        entityId: currentStage.id,
      });

      return jsonResponse({
        success: true,
        completedStageId: currentStage.id,
        nextStage: nextStage
          ? {
              id: nextStage.id,
              name: nextStage.name,
              proposedStartsAt: proposedDate,
              appointmentId: nextAppointmentId,
            }
          : null,
        planCompleted: !nextStage,
      });
    }

    // 3. Skip stage
    if (action === "skip_stage") {
      const input = stageActionSchema.parse(body);
      await service
        .from("plan_stages")
        .update({ status: "skipped", notes: input.notes })
        .eq("id", input.stageId)
        .eq("clinic_id", profile.clinic_id);

      return jsonResponse({ success: true, skippedStageId: input.stageId });
    }

    // 4. Pause plan
    if (action === "pause_plan") {
      const input = planActionSchema.parse(body);
      await service
        .from("treatment_plans")
        .update({ status: "paused", updated_at: new Date().toISOString() })
        .eq("id", input.planId)
        .eq("clinic_id", profile.clinic_id);

      return jsonResponse({ success: true, status: "paused" });
    }

    // 5. Resume plan
    if (action === "resume_plan") {
      const input = planActionSchema.parse(body);
      await service
        .from("treatment_plans")
        .update({ status: "active", updated_at: new Date().toISOString() })
        .eq("id", input.planId)
        .eq("clinic_id", profile.clinic_id);

      return jsonResponse({ success: true, status: "active" });
    }

    return errorResponse("Unknown action", 400);
  } catch (err: any) {
    return errorResponse(err?.message || "Treatment plan action failed", 400);
  }
});
