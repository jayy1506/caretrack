import { GoogleGenerativeAI } from '@google/generative-ai';
import { config, storage } from '../config/index.js';
import { ExtractedPrescriptionResponse, FollowUpType } from '../types/index.js';

export class GeminiPrescriptionService {
  private static getClient(): GoogleGenerativeAI | null {
    if (!config.geminiApiKey) {
      return null;
    }
    return new GoogleGenerativeAI(config.geminiApiKey);
  }

  public static isConfigured(): boolean {
    return Boolean(config.geminiApiKey && config.geminiApiKey.trim().length > 0);
  }

  /**
   * Extracts structured prescription data from an image buffer or Firebase Storage path.
   */
  public static async extractPrescription(params: {
    storagePath?: string;
    base64Data?: string;
    mimeType?: string;
  }): Promise<{ success: boolean; data?: ExtractedPrescriptionResponse; error?: string }> {
    if (!this.isConfigured()) {
      return {
        success: false,
        error: 'Gemini API key is not configured on the backend.',
      };
    }

    try {
      const client = this.getClient();
      if (!client) {
        throw new Error('Gemini client initialization failed.');
      }

      let imageBase64 = params.base64Data;
      let mimeType = params.mimeType || 'image/jpeg';

      // If storage path provided, download from Firebase Storage
      if (!imageBase64 && params.storagePath) {
        const bucket = storage.bucket();
        const file = bucket.file(params.storagePath);
        const [exists] = await file.exists();
        if (!exists) {
          return { success: false, error: 'Prescription file not found in storage.' };
        }
        const [buffer] = await file.download();
        imageBase64 = buffer.toString('base64');
        const [metadata] = await file.getMetadata();
        mimeType = metadata.contentType || 'image/jpeg';
      }

      if (!imageBase64) {
        return { success: false, error: 'No image data or file path provided for extraction.' };
      }

      const model = client.getGenerativeModel({ model: 'gemini-1.5-flash' });

      const prompt = `
You are a specialized medical prescription text extractor for a clinic management system.
Carefully read the provided prescription image and extract the structured medical information.

IMPORTANT RULES:
1. DO NOT fabricate or guess medicines if they are unreadable.
2. If medicine names or dosages are unclear, include what is readable or state "Unclear".
3. Extract any explicit follow-up instructions mentioned (e.g. "Review after 2 weeks", "Follow up in 1 month", "SOS").
4. Return ONLY a valid JSON object matching this exact schema:

{
  "medicines": [
    {
      "name": "string (e.g. Amoxicillin 500mg)",
      "dosage": "string (e.g. 1 tablet)",
      "frequency": "string (e.g. Twice daily after food)",
      "duration": "string (e.g. 5 days)",
      "instructions": "string (e.g. After food)"
    }
  ],
  "prescriptionDate": "YYYY-MM-DD",
  "followUpInstructions": "string or empty if none",
  "suggestedFollowUpType": "15_days" | "1_month" | "3_months" | "6_months" | "custom",
  "confidenceNote": "string noting if any part was hard to read"
}
`;

      const result = await model.generateContent([
        prompt,
        {
          inlineData: {
            data: imageBase64,
            mimeType: mimeType,
          },
        },
      ]);

      const responseText = result.response.text();
      
      // Clean JSON formatting
      const jsonMatch = responseText.match(/```(?:json)?([\s\S]*?)```/) || [null, responseText];
      const cleanedJson = (jsonMatch[1] || responseText).trim();

      const parsed = JSON.parse(cleanedJson);

      // Validate & format response
      const extracted: ExtractedPrescriptionResponse = {
        medicines: Array.isArray(parsed.medicines)
          ? parsed.medicines.map((m: any) => ({
              name: String(m.name || '').trim(),
              dosage: String(m.dosage || '').trim(),
              frequency: String(m.frequency || '').trim(),
              duration: String(m.duration || '').trim(),
              instructions: String(m.instructions || '').trim(),
            }))
          : [],
        prescriptionDate: parsed.prescriptionDate || new Date().toISOString().split('T')[0],
        followUpInstructions: parsed.followUpInstructions || '',
        suggestedFollowUpType: this.mapFollowUpType(parsed.suggestedFollowUpType, parsed.followUpInstructions),
        confidenceNote: parsed.confidenceNote || 'Extracted via Gemini AI. Please verify carefully.',
      };

      return {
        success: true,
        data: extracted,
      };
    } catch (err: any) {
      console.error('Gemini extraction error:', err);
      return {
        success: false,
        error: `Could not reliably extract prescription: ${err.message || 'Check image clarity.'}`,
      };
    }
  }

  private static mapFollowUpType(typeStr?: string, instructions?: string): FollowUpType {
    if (typeStr && ['15_days', '1_month', '3_months', '6_months', 'custom'].includes(typeStr)) {
      return typeStr as FollowUpType;
    }

    const text = (instructions || '').toLowerCase();
    if (text.includes('15') || text.includes('2 week') || text.includes('two week')) return '15_days';
    if (text.includes('1 month') || text.includes('one month') || text.includes('4 week')) return '1_month';
    if (text.includes('6 month') || text.includes('six month')) return '6_months';
    
    return '3_months'; // Default
  }
}
