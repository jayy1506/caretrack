// extract-prescription: AI vision extraction using Gemini Flash with consent check & schema validation
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getAuthenticatedUser, createServiceClient } from "../_shared/clients.ts";
import { extractPrescriptionSchema, geminiExtractionResponseSchema } from "../_shared/schemas.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { safeLog, safeError } from "../_shared/logger.ts";

const DISCLAIMER_BANNER = "AI extracted information. Please verify before saving.";

serve(async (req: Request) => {
  const corsRes = handleCors(req);
  if (corsRes) return corsRes;

  try {
    const { user, profile } = await getAuthenticatedUser(req);
    const body = await req.json();
    const input = extractPrescriptionSchema.parse(body);

    const service = createServiceClient();

    // 1. Check patient exists in clinic and has ai_consent
    const { data: patient, error: patientError } = await service
      .from("patients")
      .select("id, clinic_id, full_name, ai_consent")
      .eq("id", input.patientId)
      .single();

    if (patientError || !patient || patient.clinic_id !== profile.clinic_id) {
      return errorResponse("Patient record not found in your clinic", 404);
    }

    if (!patient.ai_consent) {
      return errorResponse(
        "Patient has not consented to AI-assisted prescription processing. Please obtain patient consent first.",
        403
      );
    }

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    // Configurable Gemini model; default to gemini-2.0-flash (avoiding hardcoded 1.5-flash)
    const geminiModel = Deno.env.get("GEMINI_MODEL") || "gemini-2.0-flash";

    let extractedData;

    // Mock response fallback when no API key is provided
    if (!geminiKey || geminiKey === "mock-gemini-key") {
      safeLog("Using mock Gemini extraction for demo");
      extractedData = {
        medicines: [
          {
            name: "Amoxicillin 500mg",
            dosage: "1 tablet",
            frequency: "Thrice daily",
            duration_days: 5,
            instructions: "Take after food",
            confidence: 0.95,
          },
          {
            name: "Paracetamol 650mg",
            dosage: "1 tablet",
            frequency: "SOS for pain",
            duration_days: 3,
            instructions: "Take with water",
            confidence: 0.92,
          },
        ],
        follow_up_days: 7,
        clinical_notes: "Extracted from synthetic handwritten prescription",
        warnings: [],
      };
    } else {
      // Call Google Gemini API
      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent?key=${geminiKey}`;

      const prompt = `You are a clinical OCR assistant for dental clinics. 
Extract all medication names, dosages, frequencies (e.g. Once daily, Twice daily, Thrice daily), duration in days, and special instructions from this prescription image.
Respond with pure JSON matching this schema:
{
  "medicines": [
    {
      "name": "string",
      "dosage": "string",
      "frequency": "string",
      "duration_days": number,
      "instructions": "string",
      "confidence": number between 0 and 1
    }
  ],
  "follow_up_days": number or null,
  "clinical_notes": "string or null",
  "warnings": ["any illegible text or ambiguities detected"]
}
Do not provide medical diagnosis or substitute clinical judgment.`;

      const response = await fetch(geminiUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { text: prompt },
                {
                  inline_data: {
                    mime_type: input.mimeType,
                    data: input.imageBase64,
                  },
                },
              ],
            },
          ],
          generationConfig: {
            response_mime_type: "application/json",
            temperature: 0.1,
          },
        }),
      });

      if (!response.ok) {
        const errBody = await response.text();
        safeError("Gemini API call failed", errBody);
        return errorResponse("Failed to process prescription image with AI", 502);
      }

      const result = await response.json();
      const rawText = result.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!rawText) {
        return errorResponse("AI model returned empty response", 500);
      }

      const jsonParsed = JSON.parse(rawText);
      extractedData = geminiExtractionResponseSchema.parse(jsonParsed);
    }

    // Write audit log
    await writeAuditLog({
      clinicId: profile.clinic_id,
      userId: user.id,
      action: "AI_EXTRACT_PRESCRIPTION",
      entity: "patients",
      entityId: patient.id,
    });

    return jsonResponse({
      banner: DISCLAIMER_BANNER,
      isAiGenerated: true,
      data: extractedData,
    });
  } catch (err: any) {
    safeError("Prescription extraction error", err);
    return errorResponse(err?.message || "Invalid request", 400);
  }
});
