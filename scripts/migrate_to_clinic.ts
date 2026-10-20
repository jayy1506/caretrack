import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();

export const DEFAULT_CLINIC_ID = 'default-clinic';

export async function runClinicMigration(clinicId: string = DEFAULT_CLINIC_ID) {
  console.log(`Starting migration to clinicId: ${clinicId}...`);

  // 1. Ensure Default Clinic Exists
  const clinicRef = db.collection('clinics').doc(clinicId);
  const clinicDoc = await clinicRef.get();

  if (!clinicDoc.exists) {
    console.log(`Creating default clinic (${clinicId})...`);
    await clinicRef.set({
      id: clinicId,
      name: 'CareTrack Dental & Healthcare Clinic',
      address: '101 Healthcare Blvd, Bandra West, Mumbai, MH 400050',
      phone: '+919876543210',
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
    console.log(`Default clinic created.`);
  }

  // Collections to migrate
  const collections = ['users', 'patients', 'prescriptions', 'appointments', 'notifications'];

  for (const colName of collections) {
    console.log(`Checking collection: ${colName}...`);
    const snapshot = await db.collection(colName).get();
    let migratedCount = 0;

    const batchSize = 400;
    let batch = db.batch();
    let opCount = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      if (!data.clinicId) {
        batch.update(doc.ref, {
          clinicId: clinicId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        opCount++;
        migratedCount++;

        // If user, also update custom claims
        if (colName === 'users') {
          const uid = doc.id;
          try {
            const userRecord = await auth.getUser(uid);
            const currentClaims = userRecord.customClaims || {};
            const role = currentClaims.role || data.role || 'doctor';
            const mappedRole = role === 'admin' ? 'owner' : role;
            await auth.setCustomUserClaims(uid, {
              ...currentClaims,
              role: mappedRole,
              clinicId: clinicId,
            });
          } catch (e: any) {
            console.warn(`Could not set custom claims for user ${uid}: ${e.message}`);
          }
        }

        if (opCount >= batchSize) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      }
    }

    if (opCount > 0) {
      await batch.commit();
    }

    console.log(`Collection ${colName}: ${migratedCount} of ${snapshot.size} records updated with clinicId.`);
  }

  console.log('Clinic migration complete!');
}

if (process.env.RUN_MIGRATION === 'true') {
  runClinicMigration().catch(console.error);
}
