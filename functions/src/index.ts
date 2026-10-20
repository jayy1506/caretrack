export { createStaffMember, createDoctor, toggleDoctorStatus } from './auth/index.js';
export {
  extractPrescriptionData,
  checkPrescriptionSafetyCallable,
  confirmPrescriptionWithSafety,
  getOptimalReminderTiming,
} from './prescriptions/index.js';
export { sendPatientRegistrationNotification } from './patients/index.js';
export {
  confirmAppointmentWeb,
  sendAppointmentConfirmation,
  predictAppointmentRisk,
  batchScoreUpcomingAppointmentsRisk,
} from './appointments/index.js';
export { scheduledReminderEngine, triggerDemoReminderCheck } from './scheduled/reminderEngine.js';
export { scheduledFirestoreBackup } from './scheduled/backupEngine.js';
export { sendDirectMessage, apiSendMessage } from './notifications/index.js';
export {
  getPlanTemplates,
  createPlanFromTemplate,
  completeStage,
  skipStage,
  pausePlan,
  resumePlan,
  onAppointmentUpdated,
} from './treatmentPlans/index.js';
export {
  getAvailableSlots,
  bookAppointmentPublic,
  verifyBookingWeb,
  manageBookingWeb,
  bookAppointmentReception,
  bookWeb,
} from './booking/index.js';
export {
  whatsappWebhook,
  getClinicConversations,
  replyConversation,
  manageConversationThread,
  getRecallCandidates,
  triggerRecallCampaign,
  sendReviewRequest,
} from './whatsapp/index.js';
export {
  generateMedicationSchedule,
  confirmMedicationSchedule,
  markMedicationTakenWeb,
  scheduledMedicationReminderEngine,
  triggerMedicationRemindersCheck,
  getPatientMedicationSchedules,
} from './medications/index.js';
export {
  exportPatientData,
  erasePatientData,
  updatePatientConsent,
  submitFeedback,
  getPilotMetrics,
} from './compliance/index.js';

