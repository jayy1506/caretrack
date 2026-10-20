import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { z } from 'zod';
import { auth, db, COLLECTIONS } from '../config/index.js';
import { UserDocument, UserRole } from '../types/index.js';
import { AuditService } from '../services/auditService.js';

const CreateStaffSchema = z.object({
  clinicId: z.string().min(1, 'clinicId is required'),
  name: z.string().min(1, 'Full name is required'),
  email: z.string().email('Valid email is required'),
  password: z.string().min(6, 'Temporary password must be at least 6 characters long'),
  role: z.enum(['doctor', 'receptionist']),
  phone: z.string().optional(),
  active: z.boolean().optional(),
});

/**
 * Callable for clinic owners to provision doctor or receptionist accounts.
 * Enforces Zod validation, caller clinic ownership, role verification, and audit logging.
 */
export const createStaffMember = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  // 1. Zod input validation
  const parseResult = CreateStaffSchema.safeParse(request.data);
  if (!parseResult.success) {
    const errorMsg = parseResult.error.errors.map((e) => e.message).join(', ');
    throw new HttpsError('invalid-argument', errorMsg);
  }

  const { clinicId, name, email, password, role, phone, active = true } = parseResult.data;

  // 2. Verify caller role & clinic ownership
  const callerUid = request.auth.uid;
  const callerClaimsRole = request.auth.token?.role;
  const callerClaimsClinicId = request.auth.token?.clinicId;

  const callerDoc = await db.collection(COLLECTIONS.USERS).doc(callerUid).get();
  const callerData = callerDoc.data();
  const callerRole: UserRole = callerClaimsRole || callerData?.role;
  const callerClinicId = callerClaimsClinicId || callerData?.clinicId;

  const isOwner = callerRole === 'owner' || callerRole === 'admin';
  if (!isOwner) {
    throw new HttpsError('permission-denied', 'Only clinic owners or administrators can create staff accounts.');
  }

  // Ensure owner manages only their own clinic (unless global admin)
  if (callerRole !== 'admin' && callerClinicId !== clinicId) {
    throw new HttpsError('permission-denied', 'You cannot create staff members for another clinic.');
  }

  // 3. Verify clinic exists
  const clinicDoc = await db.collection(COLLECTIONS.CLINICS).doc(clinicId).get();
  if (!clinicDoc.exists) {
    throw new HttpsError('not-found', `Clinic ${clinicId} does not exist.`);
  }

  try {
    // 4. Create Firebase Auth user
    const userRecord = await auth.createUser({
      email: email.trim().toLowerCase(),
      password,
      displayName: name.trim(),
      phoneNumber: phone && phone.startsWith('+') ? phone.trim() : undefined,
      disabled: !active,
    });

    // 5. Assign custom claims (role and clinicId)
    await auth.setCustomUserClaims(userRecord.uid, {
      role,
      clinicId,
    });

    // 6. Write Firestore user profile
    const newStaff: UserDocument = {
      uid: userRecord.uid,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone ? phone.trim() : undefined,
      role,
      clinicId,
      active,
      createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
      updatedAt: admin.firestore.FieldValue.serverTimestamp() as any,
    };

    await db.collection(COLLECTIONS.USERS).doc(userRecord.uid).set(newStaff);

    // 7. Write server audit log (Zero PII in log body)
    await AuditService.log({
      clinicId,
      userId: callerUid,
      action: 'staff.created',
      entityType: 'staff',
      entityId: userRecord.uid,
      details: { role, targetEmailDomain: email.split('@')[1] },
    });

    return {
      success: true,
      message: `${role === 'doctor' ? 'Doctor' : 'Receptionist'} account created for ${name}`,
      staff: {
        uid: userRecord.uid,
        name: newStaff.name,
        email: newStaff.email,
        phone: newStaff.phone,
        role: newStaff.role,
        clinicId: newStaff.clinicId,
        active: newStaff.active,
      },
    };
  } catch (error: any) {
    console.error('Error creating staff account:', error);
    if (error.code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'A user with this email address already exists.');
    }
    throw new HttpsError('internal', error.message || 'Failed to create staff account.');
  }
});

/**
 * Backward compatibility wrapper for createDoctor callable
 */
export const createDoctor = onCall({ cors: true }, async (request) => {
  const data = request.data || {};
  const clinicId = data.clinicId || request.auth?.token?.clinicId || 'default-clinic';
  return await createStaffMember.run({
    ...request,
    data: {
      ...data,
      clinicId,
      role: 'doctor',
    },
  });
});

const ToggleStaffStatusSchema = z.object({
  staffId: z.string().min(1, 'staffId is required'),
  active: z.boolean(),
  clinicId: z.string().optional(),
});

export const toggleDoctorStatus = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const parseResult = ToggleStaffStatusSchema.safeParse({
    staffId: request.data?.staffId || request.data?.doctorId,
    active: request.data?.active,
    clinicId: request.data?.clinicId,
  });

  if (!parseResult.success) {
    throw new HttpsError('invalid-argument', parseResult.error.errors.map((e) => e.message).join(', '));
  }

  const { staffId, active } = parseResult.data;
  const callerUid = request.auth.uid;
  const callerRole = request.auth.token?.role;
  const callerClinicId = request.auth.token?.clinicId;

  const callerDoc = await db.collection(COLLECTIONS.USERS).doc(callerUid).get();
  const actualRole = callerRole || callerDoc.data()?.role;
  const actualClinicId = callerClinicId || callerDoc.data()?.clinicId;

  if (actualRole !== 'owner' && actualRole !== 'admin') {
    throw new HttpsError('permission-denied', 'Only clinic owners can enable or disable staff accounts.');
  }

  // Retrieve target staff doc to check clinic match
  const staffDoc = await db.collection(COLLECTIONS.USERS).doc(staffId).get();
  if (!staffDoc.exists) {
    throw new HttpsError('not-found', 'Staff member not found.');
  }

  const staffData = staffDoc.data();
  if (actualRole !== 'admin' && staffData?.clinicId !== actualClinicId) {
    throw new HttpsError('permission-denied', 'Cannot modify staff of another clinic.');
  }

  try {
    await auth.updateUser(staffId, { disabled: !active });
    await db.collection(COLLECTIONS.USERS).doc(staffId).update({
      active,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await AuditService.log({
      clinicId: staffData?.clinicId || actualClinicId || 'default-clinic',
      userId: callerUid,
      action: active ? 'staff.enabled' : 'staff.disabled',
      entityType: 'staff',
      entityId: staffId,
      details: { role: staffData?.role },
    });

    return {
      success: true,
      message: `Staff account has been ${active ? 'enabled' : 'disabled'}.`,
    };
  } catch (err: any) {
    throw new HttpsError('internal', err.message || 'Failed to update staff status.');
  }
});
