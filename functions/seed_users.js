import admin from 'firebase-admin';
import * as dotenv from 'dotenv';
dotenv.config();

// Initialize Firebase Admin with project
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'caretrack-47af5',
  });
}

const auth = admin.auth();
const db = admin.firestore();

async function createOrUpdateUser(email, password, role, name, extraData = {}) {
  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
    console.log(`Found existing Auth user: ${email} (${userRecord.uid})`);
    await auth.updateUser(userRecord.uid, {
      password: password,
      displayName: name,
    });
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      userRecord = await auth.createUser({
        email: email,
        password: password,
        displayName: name,
      });
      console.log(`Created new Auth user: ${email} (${userRecord.uid})`);
    } else {
      throw error;
    }
  }

  // Set custom claims
  await auth.setCustomUserClaims(userRecord.uid, { role });

  // Update Firestore user document
  await db.collection('users').doc(userRecord.uid).set({
    uid: userRecord.uid,
    name,
    email,
    role,
    active: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    ...extraData,
  }, { merge: true });

  console.log(`✓ Configured ${role.toUpperCase()}: ${email} / ${password}`);
}

async function runSeed() {
  console.log('Seeding demo accounts in Firebase Auth & Firestore...');
  
  // 1. Admin
  await createOrUpdateUser(
    'admin@caretrack.com',
    'Admin@123456',
    'admin',
    'Clinic Administrator'
  );

  // 2. Doctor
  await createOrUpdateUser(
    'doctor@caretrack.com',
    'Doctor@123456',
    'doctor',
    'Dr. Sarah Jenkins (DDS)',
    {
      specialty: 'Orthodontics & General Dentistry',
      phone: '+17372508034',
    }
  );

  console.log('\n=== USERS SEEDED SUCCESSFULLY ===');
}

runSeed().catch(console.error);
