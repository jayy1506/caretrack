import * as admin from 'firebase-admin';
import { db, COLLECTIONS } from '../config/index.js';
import { AuditLogDocument } from '../types/index.js';

export interface LogAuditParams {
  clinicId: string;
  userId: string;
  action: string;
  entityType: 'patient' | 'prescription' | 'appointment' | 'staff' | 'clinic' | 'plan';
  entityId: string;
  details?: Record<string, any>;
}

/**
 * Audit service strictly for server-side recording of sensitive operations.
 * Enforces NO plaintext PII logging (names, phones, prescription notes).
 */
export class AuditService {
  public static async log(params: LogAuditParams): Promise<void> {
    try {
      const docRef = db.collection(COLLECTIONS.AUDIT_LOGS).doc();
      
      // Clean details to sanitize any accidental PII fields
      const cleanDetails = { ...(params.details || {}) };
      delete cleanDetails.patientName;
      delete cleanDetails.phone;
      delete cleanDetails.email;
      delete cleanDetails.address;
      delete cleanDetails.prescriptionText;
      delete cleanDetails.medicines;

      const auditRecord: AuditLogDocument = {
        id: docRef.id,
        clinicId: params.clinicId,
        userId: params.userId,
        action: params.action,
        entityType: params.entityType,
        entityId: params.entityId,
        details: cleanDetails,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      };

      await docRef.set(auditRecord);
    } catch (err) {
      console.error('Failed to record audit log:', err);
    }
  }
}
