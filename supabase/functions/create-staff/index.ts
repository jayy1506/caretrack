// create-staff: Owner-only endpoint to create, activate/deactivate, and update staff
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getAuthenticatedUser, createServiceClient } from "../_shared/clients.ts";
import { createStaffSchema, toggleStaffStatusSchema, updateStaffRoleSchema } from "../_shared/schemas.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { safeLog } from "../_shared/logger.ts";

serve(async (req: Request) => {
  const corsRes = handleCors(req);
  if (corsRes) return corsRes;

  try {
    const { user, profile } = await getAuthenticatedUser(req);

    // Enforce owner role
    if (profile.role !== "owner") {
      return errorResponse("Forbidden: Only clinic owners can manage staff", 403);
    }

    const body = await req.json();
    const action = body.action || "create";
    const service = createServiceClient();

    if (action === "create") {
      const parsed = createStaffSchema.parse(body);

      // Create user via Supabase Auth Admin API (passwordless invite or temporary password)
      const tempPassword = `CareTrack@${crypto.randomUUID().slice(0, 8)}`;
      const { data: newUser, error: authError } = await service.auth.admin.createUser({
        email: parsed.email,
        password: tempPassword,
        email_confirm: true,
        user_metadata: { full_name: parsed.fullName },
      });

      if (authError || !newUser.user) {
        return errorResponse(authError?.message || "Failed to create user in auth system", 400);
      }

      // Insert profile
      const { data: newProfile, error: profileError } = await service
        .from("profiles")
        .insert({
          id: newUser.user.id,
          clinic_id: profile.clinic_id,
          role: parsed.role,
          full_name: parsed.fullName,
          active: true,
        })
        .select()
        .single();

      if (profileError) {
        // Rollback auth user if profile insertion failed
        await service.auth.admin.deleteUser(newUser.user.id);
        return errorResponse("Failed to create staff profile record", 500);
      }

      await writeAuditLog({
        clinicId: profile.clinic_id,
        userId: user.id,
        action: "CREATE_STAFF",
        entity: "profiles",
        entityId: newUser.user.id,
      });

      safeLog(`Created staff member in clinic ${profile.clinic_id}`);

      // Never return password in response
      return jsonResponse({
        success: true,
        staff: {
          id: newProfile.id,
          email: parsed.email,
          role: newProfile.role,
          fullName: newProfile.full_name,
          active: newProfile.active,
        },
      });
    }

    if (action === "toggle_status") {
      const parsed = toggleStaffStatusSchema.parse(body);

      // Verify target user belongs to same clinic
      const { data: targetProfile } = await service
        .from("profiles")
        .select("id, clinic_id, role")
        .eq("id", parsed.userId)
        .single();

      if (!targetProfile || targetProfile.clinic_id !== profile.clinic_id) {
        return errorResponse("Staff member not found in your clinic", 404);
      }

      if (targetProfile.id === user.id) {
        return errorResponse("Owners cannot deactivate their own account", 400);
      }

      const { error: updateError } = await service
        .from("profiles")
        .update({ active: parsed.active })
        .eq("id", parsed.userId);

      if (updateError) return errorResponse("Failed to update staff status", 500);

      await writeAuditLog({
        clinicId: profile.clinic_id,
        userId: user.id,
        action: parsed.active ? "ACTIVATE_STAFF" : "DEACTIVATE_STAFF",
        entity: "profiles",
        entityId: parsed.userId,
      });

      return jsonResponse({ success: true, active: parsed.active });
    }

    if (action === "update_role") {
      const parsed = updateStaffRoleSchema.parse(body);

      const { data: targetProfile } = await service
        .from("profiles")
        .select("id, clinic_id, role")
        .eq("id", parsed.userId)
        .single();

      if (!targetProfile || targetProfile.clinic_id !== profile.clinic_id) {
        return errorResponse("Staff member not found in your clinic", 404);
      }

      const { error: updateError } = await service
        .from("profiles")
        .update({ role: parsed.role })
        .eq("id", parsed.userId);

      if (updateError) return errorResponse("Failed to update staff role", 500);

      await writeAuditLog({
        clinicId: profile.clinic_id,
        userId: user.id,
        action: "UPDATE_STAFF_ROLE",
        entity: "profiles",
        entityId: parsed.userId,
      });

      return jsonResponse({ success: true, role: parsed.role });
    }

    return errorResponse("Unknown action", 400);
  } catch (err: any) {
    return errorResponse(err?.message || "Internal server error", 400);
  }
});
