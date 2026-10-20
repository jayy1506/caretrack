import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { GeminiPrescriptionService } from '../services/geminiService.js';
import { FollowUpService } from '../services/followUpService.js';
import { FollowUpType } from '../types/index.js';

interface ExtractPrescriptionRequest {
  storagePath?: string;
  base64Data?: string;
  mimeType?: string;
}

export const extractPrescriptionData = onCall({ cors: true, timeoutSeconds: 60 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to extract prescriptions.');
  }

  const { storagePath, base64Data, mimeType } = request.data as ExtractPrescriptionRequest;

  if (!storagePath && !base64Data) {
    throw new HttpsError('invalid-argument', 'Either storagePath or base64Data is required.');
  }

  const result = await GeminiPrescriptionService.extractPrescription({
    storagePath,
    base64Data,
    mimeType,
  });

  if (!result.success || !result.data) {
    return {
      success: false,
      error: result.error || 'Could not extract prescription details.',
    };
  }

  // Calculate default follow-up date deterministically based on extracted suggestion
  const suggestedType: FollowUpType = result.data.suggestedFollowUpType || '3_months';
  const calculatedDate = FollowUpService.calculateFollowUpDate(
    result.data.prescriptionDate,
    suggestedType
  );

  return {
    success: true,
    data: {
      ...result.data,
      calculatedFollowUpDate: calculatedDate,
    },
  };
});
