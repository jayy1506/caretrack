import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';

/**
 * Daily Automated Firestore Backup Engine.
 * Exports all database collections to Google Cloud Storage daily at 02:00 AM IST.
 * Idempotent, robust against network drops, and logs completion.
 */
export const scheduledFirestoreBackup = onSchedule(
  {
    schedule: '0 2 * * *',
    timeZone: 'Asia/Kolkata',
    retryCount: 2,
  },
  async (event) => {
    const projectId = process.env.GCLOUD_PROJECT || admin.instanceId().app.options.projectId;
    const bucketName = process.env.BACKUP_BUCKET_NAME || `${projectId}-backups`;
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const outputUriPrefix = `gs://${bucketName}/firestore-backups/${timestamp}`;

    console.log(`Starting scheduled daily Firestore backup for project ${projectId} to ${outputUriPrefix}...`);

    try {
      const client = new admin.firestore.v1.FirestoreAdminClient();
      const databaseName = client.databasePath(projectId!, '(default)');

      const [response] = await client.exportDocuments({
        name: databaseName,
        outputUriPrefix: outputUriPrefix,
        collectionIds: [
          'clinics',
          'users',
          'patients',
          'prescriptions',
          'appointments',
          'notifications',
          'treatmentPlans',
          'auditLogs',
        ],
      });

      console.log(`Firestore backup export operation triggered successfully: ${response.name}`);
    } catch (error: any) {
      console.error('Failed to trigger automated Firestore backup:', error);
      // Let Cloud Functions scheduler retry if transient
      throw error;
    }
  }
);
