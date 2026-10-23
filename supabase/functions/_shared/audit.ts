// Audit logging utility: writes to audit_logs table via service role only
import { createServiceClient } from "./clients.ts";
import { safeLog } from "./logger.ts";

export interface AuditParams {
  clinicId?: string;
  userId?: string;
  action: string;
  entity?: string;
  entityId?: string;
}

export async function writeAuditLog(params: AuditParams): Promise<void> {
  try {
    const service = createServiceClient();
    const { error } = await service.from("audit_logs").insert({
      clinic_id: params.clinicId,
      user_id: params.userId,
      action: params.action,
      entity: params.entity,
      entity_id: params.entityId,
    });

    if (error) {
      safeLog("Failed to write audit log", { error: error.message });
    }
  } catch (err) {
    safeLog("Audit log exception", { error: String(err) });
  }
}
