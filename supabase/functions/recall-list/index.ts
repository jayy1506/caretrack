// recall-list: Identifies patients unseen for N months, at-risk treatment plans, and overdue follow-ups
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getAuthenticatedUser, createServiceClient } from "../_shared/clients.ts";
import { recallListSchema } from "../_shared/schemas.ts";
import { maskPhone } from "../_shared/phone.ts";

serve(async (req: Request) => {
  const corsRes = handleCors(req);
  if (corsRes) return corsRes;

  try {
    const { profile } = await getAuthenticatedUser(req);
    const url = new URL(req.url);
    const unseenMonths = parseInt(url.searchParams.get("unseenMonths") || "6", 10);

    const input = recallListSchema.parse({ unseenMonths });
    const service = createServiceClient();

    const cutoffDate = new Date();
    cutoffDate.setMonth(cutoffDate.getMonth() - input.unseenMonths);
    const cutoffIso = cutoffDate.toISOString();

    // 1. Fetch clinic patients with messaging consent
    const { data: patients, error: patientError } = await service
      .from("patients")
      .select("id, full_name, phone, messaging_consent, created_at, doctor_id, profiles(full_name)")
      .eq("clinic_id", profile.clinic_id);

    if (patientError || !patients) {
      return errorResponse("Failed to query patients", 500);
    }

    // 2. Fetch last appointment date for each patient
    const { data: appointments } = await service
      .from("appointments")
      .select("patient_id, starts_at, status")
      .eq("clinic_id", profile.clinic_id)
      .in("status", ["completed", "confirmed"])
      .order("starts_at", { ascending: false });

    const lastSeenMap = new Map<string, Date>();
    for (const a of appointments || []) {
      if (!lastSeenMap.has(a.patient_id)) {
        lastSeenMap.set(a.patient_id, new Date(a.starts_at));
      }
    }

    // 3. Fetch overdue prescriptions follow-up
    const { data: overdueRxs } = await service
      .from("prescriptions")
      .select("patient_id, follow_up_date")
      .eq("clinic_id", profile.clinic_id)
      .lt("follow_up_date", new Date().toISOString().split("T")[0]);

    const overdueRxSet = new Set((overdueRxs || []).map((r) => r.patient_id));

    // 4. Fetch at-risk treatment plans (active plans with no appointments scheduled in 30+ days)
    const { data: pausedPlans } = await service
      .from("treatment_plans")
      .select("patient_id, status")
      .eq("clinic_id", profile.clinic_id)
      .eq("status", "paused");

    const pausedPlanSet = new Set((pausedPlans || []).map((p) => p.patient_id));

    // 5. Check if messaged within the last 14 days (cooldown filter)
    const fourteenDaysAgo = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString();
    const { data: recentNotifs } = await service
      .from("notifications")
      .select("patient_id")
      .eq("clinic_id", profile.clinic_id)
      .gte("created_at", fourteenDaysAgo);

    const recentlyMessagedSet = new Set((recentNotifs || []).map((n) => n.patient_id));

    const recallCandidates = [];

    for (const p of patients) {
      const lastSeen = lastSeenMap.get(p.id) || new Date(p.created_at);
      const isUnseen = lastSeen < cutoffDate;
      const isOverdueRx = overdueRxSet.has(p.id);
      const hasPausedPlan = pausedPlanSet.has(p.id);
      const isRecentlyMessaged = recentlyMessagedSet.has(p.id);

      if (isUnseen || isOverdueRx || hasPausedPlan) {
        let reason = "Routine hygiene recall (unseen 6+ months)";
        if (isOverdueRx) reason = "Prescription follow-up date overdue";
        if (hasPausedPlan) reason = "Incomplete treatment plan follow-up";

        recallCandidates.push({
          patientId: p.id,
          fullName: p.full_name,
          phoneMasked: maskPhone(p.phone || ""),
          hasConsent: p.messaging_consent,
          lastSeen: lastSeen.toISOString(),
          isRecentlyMessaged,
          eligibleForRecall: p.messaging_consent && !isRecentlyMessaged,
          reason,
          doctorName: (p.profiles as any)?.full_name || "Assigned Doctor",
        });
      }
    }

    return jsonResponse({
      unseenMonths: input.unseenMonths,
      totalCandidates: recallCandidates.length,
      eligibleCandidates: recallCandidates.filter((c) => c.eligibleForRecall).length,
      candidates: recallCandidates,
    });
  } catch (err: any) {
    return errorResponse(err?.message || "Recall list query failed", 400);
  }
});
