import * as admin from 'firebase-admin';
import * as dotenv from 'dotenv';

dotenv.config();

if (!admin.apps.length) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const auth = admin.auth();
export const storage = admin.storage();
export const messaging = admin.messaging();

export const config = {
  geminiApiKey: process.env.GEMINI_API_KEY || '',
  geminiModel: process.env.GEMINI_MODEL || 'gemini-2.5-flash',
  gmailUser: process.env.GMAIL_USER || '',
  gmailAppPassword: process.env.GMAIL_APP_PASSWORD || '',
  messagingProvider: (process.env.MESSAGING_PROVIDER || 'whatsapp') as 'whatsapp' | 'telegram' | 'none',
  whatsappPhoneNumberId: process.env.WHATSAPP_PHONE_NUMBER_ID || '',
  whatsappAccessToken: process.env.WHATSAPP_ACCESS_TOKEN || '',
  whatsappAppSecret: process.env.WHATSAPP_APP_SECRET || '',
  whatsappVerifyToken: process.env.WHATSAPP_VERIFY_TOKEN || 'caretrack_webhook_token',
  telegramBotToken: process.env.TELEGRAM_BOT_TOKEN || '',
  baseAppUrl: process.env.BASE_APP_URL || 'https://caretrack-47af5.web.app',
};

// Collections
export const COLLECTIONS = {
  CLINICS: 'clinics',
  USERS: 'users',
  PATIENTS: 'patients',
  PRESCRIPTIONS: 'prescriptions',
  APPOINTMENTS: 'appointments',
  NOTIFICATIONS: 'notifications',
  TREATMENT_PLANS: 'treatmentPlans',
  PLAN_TEMPLATES: 'planTemplates',
  RECALL_LIST: 'recallList',
  RECALL_CAMPAIGNS: 'recallCampaigns',
  CONVERSATIONS: 'conversations',
  CARE_TEMPLATES: 'careTemplates',
  MEDICATION_SCHEDULES: 'medicationSchedules',
  MEDICATION_REMINDERS_LOG: 'medicationRemindersLog',
  CLINIC_DOCUMENTS: 'clinicDocuments',
  AUDIT_LOGS: 'auditLogs',
  FEEDBACK: 'feedback',
} as const;
