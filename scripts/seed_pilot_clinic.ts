import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export const PILOT_CLINIC_ID = 'pilot-dental-clinic';

export async function seedPilotClinic() {
  console.log(`\n======================================================`);
  console.log(`  Seeding CareTrack Pilot Clinic: ${PILOT_CLINIC_ID}  `);
  console.log(`======================================================\n`);

  const now = new Date();
  const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  const in3Days = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
  const in5Days = new Date(now.getTime() + 5 * 24 * 60 * 60 * 1000);
  const nextMonday = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

  // 1. Clinic Entity
  console.log(`1. Creating Pilot Clinic entity...`);
  const clinicRef = db.collection('clinics').doc(PILOT_CLINIC_ID);
  await clinicRef.set({
    id: PILOT_CLINIC_ID,
    name: 'SmileCraft Dental Studio (Pilot)',
    address: 'Suite 402, Lotus Grand, Bandra West, Mumbai, MH 400050',
    phone: '+919820011223',
    timezone: 'Asia/Kolkata',
    workingHours: {
      monday: { open: '09:00', close: '19:00', isOpen: true },
      tuesday: { open: '09:00', close: '19:00', isOpen: true },
      wednesday: { open: '09:00', close: '19:00', isOpen: true },
      thursday: { open: '09:00', close: '19:00', isOpen: true },
      friday: { open: '09:00', close: '19:00', isOpen: true },
      saturday: { open: '09:00', close: '17:00', isOpen: true },
      sunday: { open: '10:00', close: '14:00', isOpen: false },
    },
    holidays: ['2026-01-26', '2026-08-15', '2026-10-02', '2026-11-08'],
    logoUrl: '',
    featureFlags: {
      treatmentPlans: true,
      onlineBooking: true,
      twoWayWhatsApp: true,
      recall: true,
      medicationReminders: true,
      noShowAI: true,
      faqAssistant: true,
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 2. Staff Profiles (Owner, Doctor, Receptionist)
  console.log(`2. Seeding Staff Members...`);
  const staff = [
    {
      uid: 'pilot-owner-doc',
      name: 'Dr. Aarav Patel',
      email: 'aarav.patel@smilecraftdental.in',
      phone: '+919820011221',
      role: 'owner',
      clinicId: PILOT_CLINIC_ID,
      active: true,
    },
    {
      uid: 'pilot-associate-doc',
      name: 'Dr. Meera Iyer',
      email: 'meera.iyer@smilecraftdental.in',
      phone: '+919820011222',
      role: 'doctor',
      clinicId: PILOT_CLINIC_ID,
      active: true,
    },
    {
      uid: 'pilot-receptionist',
      name: 'Rohan Sharma',
      email: 'rohan.reception@smilecraftdental.in',
      phone: '+919820011224',
      role: 'receptionist',
      clinicId: PILOT_CLINIC_ID,
      active: true,
    },
  ];

  for (const member of staff) {
    await db.collection('users').doc(member.uid).set({
      ...member,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // 3. Patients with DPDP Consent Records
  console.log(`3. Seeding Patients with DPDP Consent...`);
  const patients = [
    {
      id: 'pilot-pt-1',
      clinicId: PILOT_CLINIC_ID,
      doctorId: 'pilot-owner-doc',
      name: 'Ramesh Verma',
      age: 52,
      dateOfBirth: '1974-05-12',
      phone: '+919811122233',
      email: 'ramesh.verma@example.com',
      address: 'Apt 4B, Silver Heights, Pali Hill, Mumbai',
      allergies: ['Penicillin'],
      preferredReminderHour: 9,
      status: 'active',
      messagingConsent: true,
      aiProcessingConsent: true,
      consentRecord: {
        messagingConsent: true,
        messagingConsentMethod: 'in_person',
        messagingConsentTimestamp: now.toISOString(),
        aiProcessingConsent: true,
        aiProcessingConsentMethod: 'in_person',
        aiProcessingConsentTimestamp: now.toISOString(),
        consentNotes: 'Intake signed on consultation form #201',
      },
    },
    {
      id: 'pilot-pt-2',
      clinicId: PILOT_CLINIC_ID,
      doctorId: 'pilot-associate-doc',
      name: 'Priya Sharma',
      age: 29,
      dateOfBirth: '1997-11-20',
      phone: '+919822233344',
      email: 'priya.sharma@example.com',
      address: 'Flat 12, Sunrise Residency, Khar West, Mumbai',
      allergies: [],
      preferredReminderHour: 10,
      status: 'active',
      messagingConsent: true,
      aiProcessingConsent: true,
      consentRecord: {
        messagingConsent: true,
        messagingConsentMethod: 'whatsapp_opt_in',
        messagingConsentTimestamp: now.toISOString(),
        aiProcessingConsent: true,
        aiProcessingConsentMethod: 'web_booking',
        aiProcessingConsentTimestamp: now.toISOString(),
        consentNotes: 'Double opted-in via WhatsApp onboarding link',
      },
    },
    {
      id: 'pilot-pt-3',
      clinicId: PILOT_CLINIC_ID,
      doctorId: 'pilot-owner-doc',
      name: 'Anita Desai',
      age: 41,
      dateOfBirth: '1985-03-15',
      phone: '+919833344455',
      email: 'anita.desai@example.com',
      address: 'Villa 7, Sea Green Enclave, Bandra, Mumbai',
      allergies: ['Latex'],
      preferredReminderHour: 18,
      status: 'active',
      messagingConsent: true,
      aiProcessingConsent: true,
      consentRecord: {
        messagingConsent: true,
        messagingConsentMethod: 'web_booking',
        messagingConsentTimestamp: now.toISOString(),
        aiProcessingConsent: true,
        aiProcessingConsentMethod: 'web_booking',
        aiProcessingConsentTimestamp: now.toISOString(),
        consentNotes: 'Slot booking widget explicit consent checked',
      },
    },
    {
      id: 'pilot-pt-4',
      clinicId: PILOT_CLINIC_ID,
      doctorId: 'pilot-associate-doc',
      name: 'Vikram Malhotra',
      age: 65,
      dateOfBirth: '1961-08-04',
      phone: '+919844455566',
      email: 'vikram.m@example.com',
      address: '102, Gulmohar Avenue, Juhu, Mumbai',
      allergies: ['Sulfa drugs'],
      preferredReminderHour: 11,
      status: 'active',
      messagingConsent: true,
      aiProcessingConsent: true,
      consentRecord: {
        messagingConsent: true,
        messagingConsentMethod: 'paper_form',
        messagingConsentTimestamp: now.toISOString(),
        aiProcessingConsent: true,
        aiProcessingConsentMethod: 'paper_form',
        aiProcessingConsentTimestamp: now.toISOString(),
        consentNotes: 'Physical signature on file',
      },
    },
    {
      id: 'pilot-pt-5',
      clinicId: PILOT_CLINIC_ID,
      doctorId: 'pilot-owner-doc',
      name: 'Sunita Rao',
      age: 34,
      dateOfBirth: '1992-02-18',
      phone: '+919855566677',
      email: 'sunita.rao@example.com',
      address: 'B-304, Green Acres, Santacruz West, Mumbai',
      allergies: [],
      preferredReminderHour: 12,
      status: 'active',
      messagingConsent: false,
      aiProcessingConsent: true,
      consentRecord: {
        messagingConsent: false,
        messagingConsentMethod: 'in_person',
        messagingConsentTimestamp: now.toISOString(),
        aiProcessingConsent: true,
        aiProcessingConsentMethod: 'in_person',
        aiProcessingConsentTimestamp: now.toISOString(),
        consentNotes: 'Opted out of promotional & marketing messages',
      },
    },
  ];

  for (const patient of patients) {
    await db.collection('patients').doc(patient.id).set({
      ...patient,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // 4. Structured Treatment Plans
  console.log(`4. Seeding Structured Treatment Plans...`);
  const treatmentPlans = [
    {
      id: 'plan-ramesh-rct',
      clinicId: PILOT_CLINIC_ID,
      patientId: 'pilot-pt-1',
      doctorId: 'pilot-owner-doc',
      title: 'Root Canal Treatment & Zirconia Crown (#46)',
      status: 'in_progress',
      stages: [
        {
          stageNumber: 1,
          name: 'Pulpectomy & Canal Debridement',
          status: 'completed',
          completedAt: yesterday.toISOString(),
          recommendedIntervalDays: 0,
        },
        {
          stageNumber: 2,
          name: 'Biomechanical Preparation & Obturation',
          status: 'scheduled',
          scheduledDate: tomorrow.toISOString().split('T')[0],
          scheduledTime: '10:30 AM',
          recommendedIntervalDays: 3,
        },
        {
          stageNumber: 3,
          name: 'Core Buildup & Zirconia Crown Cementation',
          status: 'pending',
          recommendedIntervalDays: 7,
        },
      ],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'plan-anita-perio',
      clinicId: PILOT_CLINIC_ID,
      patientId: 'pilot-pt-3',
      doctorId: 'pilot-owner-doc',
      title: 'Full Mouth Periodontal Maintenance & Deep Scaling',
      status: 'in_progress',
      stages: [
        {
          stageNumber: 1,
          name: 'Full Mouth Ultrasonic Scaling & Polishing',
          status: 'completed',
          completedAt: yesterday.toISOString(),
          recommendedIntervalDays: 0,
        },
        {
          stageNumber: 2,
          name: 'Subgingival Curettage (Upper & Lower Quadrants)',
          status: 'scheduled',
          scheduledDate: in3Days.toISOString().split('T')[0],
          scheduledTime: '04:00 PM',
          recommendedIntervalDays: 5,
        },
        {
          stageNumber: 3,
          name: '3-Month Periodontal Evaluation & Pocket Probing',
          status: 'pending',
          recommendedIntervalDays: 90,
        },
      ],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ];

  for (const plan of treatmentPlans) {
    await db.collection('treatmentPlans').doc(plan.id).set(plan);
  }

  // 5. Appointments
  console.log(`5. Seeding Realistic Appointments...`);
  const appointments = [
    {
      id: 'appt-ramesh-obturation',
      clinicId: PILOT_CLINIC_ID,
      doctorId: 'pilot-owner-doc',
      patientId: 'pilot-pt-1',
      date: tomorrow.toISOString().split('T')[0],
      time: '10:30 AM',
      type: 'Root Canal Stage 2',
      reason: 'Obturation & Sealant for Tooth #46',
      status: 'confirmed',
      treatmentPlanId: 'plan-ramesh-rct',
      treatmentPlanStageNumber: 2,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'appt-priya-aligner',
      clinicId: PILOT_CLINIC_ID,
      doctorId: 'pilot-associate-doc',
      patientId: 'pilot-pt-2',
      date: nextMonday.toISOString().split('T')[0],
      time: '11:00 AM',
      type: 'Orthodontic Review',
      reason: 'Clear Aligner Fitment & Progress Check #4',
      status: 'confirmed',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'appt-anita-curettage',
      clinicId: PILOT_CLINIC_ID,
      doctorId: 'pilot-owner-doc',
      patientId: 'pilot-pt-3',
      date: in3Days.toISOString().split('T')[0],
      time: '04:00 PM',
      type: 'Periodontal Care',
      reason: 'Subgingival Curettage',
      status: 'pending',
      treatmentPlanId: 'plan-anita-perio',
      treatmentPlanStageNumber: 2,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'appt-vikram-suture',
      clinicId: PILOT_CLINIC_ID,
      doctorId: 'pilot-associate-doc',
      patientId: 'pilot-pt-4',
      date: yesterday.toISOString().split('T')[0],
      time: '05:30 PM',
      type: 'Post-Op Review',
      reason: 'Implant Post-Surgical Healing Assessment',
      status: 'completed',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'appt-sunita-reschedule',
      clinicId: PILOT_CLINIC_ID,
      doctorId: 'pilot-owner-doc',
      patientId: 'pilot-pt-5',
      date: in5Days.toISOString().split('T')[0],
      time: '02:00 PM',
      type: 'Cosmetic Consultation',
      reason: 'Porcelain Veneer Shade Matching',
      status: 'reschedule_requested',
      rescheduleRequestedSlot: 'Evening after 5:00 PM preferred',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ];

  for (const appt of appointments) {
    await db.collection('appointments').doc(appt.id).set(appt);
  }

  // 6. Medication Reminders & Adherence Tracking
  console.log(`6. Seeding Medication Schedules & Adherence...`);
  const medSchedule = {
    id: 'med-ramesh-post-rct',
    clinicId: PILOT_CLINIC_ID,
    patientId: 'pilot-pt-1',
    doctorId: 'pilot-owner-doc',
    prescriptionId: 'rx-ramesh-1',
    medicines: [
      {
        name: 'Amoxicillin 500mg',
        dosage: '1 capsule',
        frequency: 'Thrice daily (8h)',
        instructions: 'Take after meals with a full glass of water',
        timesPerDay: ['08:00', '14:00', '20:00'],
      },
      {
        name: 'Ibuprofen 400mg',
        dosage: '1 tablet',
        frequency: 'Twice daily (as needed for pain)',
        instructions: 'Take after food',
        timesPerDay: ['09:00', '21:00'],
      },
    ],
    startDate: yesterday.toISOString().split('T')[0],
    endDate: in5Days.toISOString().split('T')[0],
    active: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await db.collection('medicationSchedules').doc(medSchedule.id).set(medSchedule);

  // Dose logs for yesterday and today
  const doseLogs = [
    {
      id: 'dose-1',
      scheduleId: medSchedule.id,
      patientId: 'pilot-pt-1',
      medicineName: 'Amoxicillin 500mg',
      scheduledTime: '08:00',
      status: 'taken',
      takenAt: yesterday.toISOString(),
    },
    {
      id: 'dose-2',
      scheduleId: medSchedule.id,
      patientId: 'pilot-pt-1',
      medicineName: 'Amoxicillin 500mg',
      scheduledTime: '14:00',
      status: 'taken',
      takenAt: yesterday.toISOString(),
    },
    {
      id: 'dose-3',
      scheduleId: medSchedule.id,
      patientId: 'pilot-pt-1',
      medicineName: 'Amoxicillin 500mg',
      scheduledTime: '20:00',
      status: 'taken',
      takenAt: yesterday.toISOString(),
    },
    {
      id: 'dose-4',
      scheduleId: medSchedule.id,
      patientId: 'pilot-pt-1',
      medicineName: 'Amoxicillin 500mg',
      scheduledTime: '08:00',
      status: 'taken',
      takenAt: now.toISOString(),
    },
  ];

  for (const log of doseLogs) {
    await db.collection('medicationAdherence').doc(log.id).set({
      ...log,
      clinicId: PILOT_CLINIC_ID,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // 7. Clinic WhatsApp Two-Way Inbox Threads
  console.log(`7. Seeding WhatsApp Clinic Inbox Conversations...`);
  const threads = [
    {
      id: 'thread-priya-aligners',
      clinicId: PILOT_CLINIC_ID,
      patientId: 'pilot-pt-2',
      patientPhone: '+919822233344',
      patientName: 'Priya Sharma',
      lastMessage: 'All clear, thank you Dr. Meera! See you Monday at 11 AM.',
      lastMessageTime: now.toISOString(),
      unreadCount: 0,
      triageStatus: 'routine',
      messages: [
        {
          id: 'msg-1',
          sender: 'patient',
          senderName: 'Priya Sharma',
          text: 'Hi Dr. Meera, should I wear tray 4 for 10 days or 14 days?',
          timestamp: yesterday.toISOString(),
        },
        {
          id: 'msg-2',
          sender: 'clinic',
          senderName: 'Dr. Meera Iyer',
          text: 'Hello Priya, wear tray 4 for 14 full days since tooth #12 is still rotating slightly. Keep tracking!',
          timestamp: yesterday.toISOString(),
        },
        {
          id: 'msg-3',
          sender: 'patient',
          senderName: 'Priya Sharma',
          text: 'All clear, thank you Dr. Meera! See you Monday at 11 AM.',
          timestamp: now.toISOString(),
        },
      ],
    },
    {
      id: 'thread-ramesh-pain',
      clinicId: PILOT_CLINIC_ID,
      patientId: 'pilot-pt-1',
      patientPhone: '+919811122233',
      patientName: 'Ramesh Verma',
      lastMessage: 'Got it, looking forward to tomorrow 10:30 AM.',
      lastMessageTime: now.toISOString(),
      unreadCount: 0,
      triageStatus: 'routine',
      messages: [
        {
          id: 'msg-4',
          sender: 'patient',
          senderName: 'Ramesh Verma',
          text: 'Doctor, experiencing slight sensitivity when drinking cold water after yesterday’s drilling.',
          timestamp: yesterday.toISOString(),
        },
        {
          id: 'msg-5',
          sender: 'clinic',
          senderName: 'Dr. Aarav Patel',
          text: 'Mild sensitivity to cold is expected after canal debridement, Ramesh. Take your prescribed Ibuprofen if uncomfortable. We will obturate and seal it tomorrow at 10:30 AM.',
          timestamp: yesterday.toISOString(),
        },
        {
          id: 'msg-6',
          sender: 'patient',
          senderName: 'Ramesh Verma',
          text: 'Got it, looking forward to tomorrow 10:30 AM.',
          timestamp: now.toISOString(),
        },
      ],
    },
  ];

  for (const thread of threads) {
    const threadRef = db.collection('messages').doc(thread.id);
    await threadRef.set({
      clinicId: thread.clinicId,
      patientId: thread.patientId,
      patientPhone: thread.patientPhone,
      patientName: thread.patientName,
      lastMessage: thread.lastMessage,
      lastMessageTime: thread.lastMessageTime,
      unreadCount: thread.unreadCount,
      triageStatus: thread.triageStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    for (const msg of thread.messages) {
      await threadRef.collection('chat').doc(msg.id).set({
        ...msg,
        clinicId: thread.clinicId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  console.log(`\n======================================================`);
  console.log(`  Pilot Clinic Pre-Seeding Completed Successfully!    `);
  console.log(`  Clinic ID: ${PILOT_CLINIC_ID}                       `);
  console.log(`  Staff: 3 (Owner, Doctor, Receptionist)              `);
  console.log(`  Patients: 5 (with DPDP consent flags)               `);
  console.log(`  Treatment Plans: 2 (multi-stage)                   `);
  console.log(`  Appointments: 5 (mix of statuses)                  `);
  console.log(`  Medication Schedules: 1 (with dose adherence)      `);
  console.log(`  Inbox Threads: 2 (two-way WhatsApp)                `);
  console.log(`======================================================\n`);
}

// Execute if invoked directly
if (process.argv[1]?.endsWith('seed_pilot_clinic.ts') || process.argv[1]?.endsWith('seed_pilot_clinic.js')) {
  seedPilotClinic().catch((err) => {
    console.error('Failed to seed pilot clinic:', err);
    process.exit(1);
  });
}
