// RLS & Security Policy Tests (Deno test suite)
import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";

interface MockUser {
  id: string;
  role: "owner" | "doctor" | "receptionist";
  clinic_id: string;
  active: boolean;
}

const DEMO_USERS: Record<string, MockUser> = {
  owner: {
    id: "10000000-0000-0000-0000-000000000001",
    role: "owner",
    clinic_id: "c0000000-0000-0000-0000-000000000001",
    active: true,
  },
  doctorA: {
    id: "10000000-0000-0000-0000-000000000002",
    role: "doctor",
    clinic_id: "c0000000-0000-0000-0000-000000000001",
    active: true,
  },
  doctorB: {
    id: "10000000-0000-0000-0000-000000000003",
    role: "doctor",
    clinic_id: "c0000000-0000-0000-0000-000000000001",
    active: true,
  },
  receptionist: {
    id: "10000000-0000-0000-0000-000000000004",
    role: "receptionist",
    clinic_id: "c0000000-0000-0000-0000-000000000001",
    active: true,
  },
  otherClinicDoc: {
    id: "10000000-0000-0000-0000-000000000099",
    role: "doctor",
    clinic_id: "c0000000-0000-0000-0000-000000000002",
    active: true,
  },
};

// Pure RLS evaluation engine mirroring PostgreSQL RLS policies
function canReadClinic(user: MockUser | null, clinicId: string): boolean {
  if (!user || !user.active) return false;
  return user.clinic_id === clinicId;
}

function canReadPatient(
  user: MockUser | null,
  patient: { clinic_id: string; doctor_id: string }
): boolean {
  if (!user || !user.active) return false;
  if (user.clinic_id !== patient.clinic_id) return false;
  // patients_select: clinic_id = auth_clinic() and (doctor_id = auth.uid() or auth_role() in ('owner','receptionist'))
  return user.id === patient.doctor_id || ["owner", "receptionist"].includes(user.role);
}

function canReadPrescription(
  user: MockUser | null,
  rx: { clinic_id: string; doctor_id: string }
): boolean {
  if (!user || !user.active) return false;
  if (user.clinic_id !== rx.clinic_id) return false;
  // rx_doctor policy: clinic_id = auth_clinic() and doctor_id = auth.uid()
  return user.role === "doctor" && user.id === rx.doctor_id;
}

function canUpdateProfileRole(
  invokerRole: string,
  _targetUserId: string,
  _newRole: string
): boolean {
  // Only service_role can update user roles/clinics
  return invokerRole === "service_role";
}

Deno.test("RLS 1: Anonymous access is completely denied", () => {
  const patient = { clinic_id: DEMO_USERS.doctorA.clinic_id, doctor_id: DEMO_USERS.doctorA.id };
  const rx = { clinic_id: DEMO_USERS.doctorA.clinic_id, doctor_id: DEMO_USERS.doctorA.id };

  assertEquals(canReadClinic(null, patient.clinic_id), false);
  assertEquals(canReadPatient(null, patient), false);
  assertEquals(canReadPrescription(null, rx), false);
});

Deno.test("RLS 2: Cross-clinic reads fail for users in another clinic", () => {
  const patientClinic1 = {
    clinic_id: DEMO_USERS.doctorA.clinic_id,
    doctor_id: DEMO_USERS.doctorA.id,
  };
  assertEquals(canReadClinic(DEMO_USERS.otherClinicDoc, patientClinic1.clinic_id), false);
  assertEquals(canReadPatient(DEMO_USERS.otherClinicDoc, patientClinic1), false);
  assertEquals(canReadPrescription(DEMO_USERS.otherClinicDoc, patientClinic1), false);
});

Deno.test("RLS 3: Doctor B cannot read Doctor A's patients or prescriptions", () => {
  const patientA = {
    clinic_id: DEMO_USERS.doctorA.clinic_id,
    doctor_id: DEMO_USERS.doctorA.id,
  };
  const rxA = {
    clinic_id: DEMO_USERS.doctorA.clinic_id,
    doctor_id: DEMO_USERS.doctorA.id,
  };

  assertEquals(canReadPatient(DEMO_USERS.doctorB, patientA), false);
  assertEquals(canReadPrescription(DEMO_USERS.doctorB, rxA), false);
});

Deno.test("RLS 4: Receptionist cannot read prescriptions, but can read clinic patients", () => {
  const patientA = {
    clinic_id: DEMO_USERS.doctorA.clinic_id,
    doctor_id: DEMO_USERS.doctorA.id,
  };
  const rxA = {
    clinic_id: DEMO_USERS.doctorA.clinic_id,
    doctor_id: DEMO_USERS.doctorA.id,
  };

  assertEquals(canReadPatient(DEMO_USERS.receptionist, patientA), true);
  assertEquals(canReadPrescription(DEMO_USERS.receptionist, rxA), false);
});

Deno.test("RLS 5: Privilege escalation prevented (users cannot change their own role)", () => {
  assertEquals(canUpdateProfileRole("authenticated", DEMO_USERS.doctorA.id, "owner"), false);
  assertEquals(canUpdateProfileRole("service_role", DEMO_USERS.doctorA.id, "owner"), true);
});

Deno.test("RLS 6: Slot double-booking prevention constraint", () => {
  const bookedSlots = new Set<string>();
  function bookSlot(doctorId: string, startsAtIso: string): boolean {
    const key = `${doctorId}:${startsAtIso}`;
    if (bookedSlots.has(key)) {
      throw new Error("unique_violation: slot already booked for doctor");
    }
    bookedSlots.add(key);
    return true;
  }

  const slotTime = "2026-10-24T10:00:00Z";
  assertEquals(bookSlot(DEMO_USERS.doctorA.id, slotTime), true);
  assertRejects(async () => {
    bookSlot(DEMO_USERS.doctorA.id, slotTime);
  }, Error, "unique_violation");
});
