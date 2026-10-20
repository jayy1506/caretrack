import { describe, it, expect } from 'vitest';
import * as fs from 'fs';
import * as path from 'path';
import { PrescriptionEvalRunner, EvalSample } from '../../tools/eval/eval_runner.js';
import { PrescriptionSafetyService } from '../src/services/prescriptionSafetyService.js';
import { NoShowPredictionService } from '../src/services/noShowPredictionService.js';
import { SmartTimingService } from '../src/services/smartTimingService.js';
import { FaqAssistantService } from '../src/services/faqAssistantService.js';

describe('Phase 6: AI Features (Suggestions, Human-Confirmed)', () => {
  // ---------------------------------------------------------
  // 1. Prescription Extraction Evaluation
  // ---------------------------------------------------------
  describe('Prescription Extraction Evaluation Runner', () => {
    it('accurately evaluates synthetic dataset samples and computes per-field accuracy', () => {
      const sample1Path = path.resolve(__dirname, '../../tools/eval/dataset/sample_1.json');
      const sample2Path = path.resolve(__dirname, '../../tools/eval/dataset/sample_2.json');

      const sample1: EvalSample = JSON.parse(fs.readFileSync(sample1Path, 'utf8'));
      const sample2: EvalSample = JSON.parse(fs.readFileSync(sample2Path, 'utf8'));

      // Mock extracted output matching sample 1 and slight variation in sample 2
      const mockExtractions = {
        [sample1.id]: {
          medicines: [
            { name: 'Amoxicillin 500mg', dosage: '1 cap', frequency: 'TDS', duration: '5 days' },
            { name: 'Combiflam', dosage: '1 tab', frequency: 'BD', duration: '3 days' },
            { name: 'Chlorhexidine Mouthwash 0.2%', dosage: '10ml', frequency: 'BD', duration: '7 days' },
          ],
          prescriptionDate: '2026-10-15',
        },
        [sample2.id]: {
          medicines: [
            { name: 'Augmentin 625mg', dosage: '1 tablet', frequency: 'Twice daily', duration: '5 days' },
            { name: 'Ketorol DT', dosage: '1 tab', frequency: 'TDS', duration: '2 days' },
            { name: 'Pantop 40mg', dosage: '1 tab', frequency: 'OD', duration: '5 days' },
          ],
          prescriptionDate: '2026-10-18',
        },
      };

      const report = PrescriptionEvalRunner.evaluate([sample1, sample2], mockExtractions);

      expect(report.nameAccuracy).toBe(1.0);
      expect(report.dosageAccuracy).toBeGreaterThanOrEqual(0.85);
      expect(report.frequencyAccuracy).toBeGreaterThanOrEqual(0.85);
      expect(report.durationAccuracy).toBe(1.0);
      expect(report.overallAccuracy).toBeGreaterThanOrEqual(0.9);
      expect(report.precision).toBe(1.0);
      expect(report.recall).toBe(1.0);
      expect(report.f1Score).toBe(1.0);

      const markdown = PrescriptionEvalRunner.generateMarkdownReport(report);
      expect(markdown).toContain('# Prescription Extraction Evaluation Report');
      expect(markdown).toContain('Medicine Name Accuracy');
      expect(markdown).toContain('SYNTHETIC/SAMPLE');

      // Write report artifact
      const reportPath = path.resolve(__dirname, '../../tools/eval/eval_report.md');
      fs.writeFileSync(reportPath, markdown, 'utf8');
      expect(fs.existsSync(reportPath)).toBe(true);
    });
  });

  // ---------------------------------------------------------
  // 2. Prescription Safety Checks
  // ---------------------------------------------------------
  describe('Prescription Safety Service', () => {
    it('detects penicillin allergy conflict when amoxicillin is prescribed', () => {
      const result = PrescriptionSafetyService.checkPrescriptionSafety({
        patientAllergies: ['Penicillin', 'Sulfa'],
        medicines: [
          {
            name: 'Amoxicillin 500mg',
            dosage: '1 cap',
            frequency: 'TDS',
            duration: '5 days',
            instructions: 'After food',
          },
          {
            name: 'Paracetamol 650mg',
            dosage: '1 tab',
            frequency: 'SOS',
            duration: '3 days',
            instructions: 'For fever',
          },
        ],
      });

      expect(result.hasWarnings).toBe(true);
      const allergyWarning = result.warnings.find((w) => w.type === 'allergy_conflict');
      expect(allergyWarning).toBeDefined();
      expect(allergyWarning?.severity).toBe('danger');
      expect(allergyWarning?.medicineName).toBe('Amoxicillin 500mg');
      expect(allergyWarning?.message).toContain('ALLERGY WARNING');
    });

    it('detects NSAID allergy conflict when Combiflam or Ibuprofen is prescribed', () => {
      const result = PrescriptionSafetyService.checkPrescriptionSafety({
        patientAllergies: ['Aspirin', 'NSAIDs'],
        medicines: [
          {
            name: 'Combiflam (Ibuprofen + Paracetamol)',
            dosage: '1 tab',
            frequency: 'BD',
            duration: '3 days',
            instructions: 'After food',
          },
        ],
      });

      expect(result.hasWarnings).toBe(true);
      const conflict = result.warnings.find((w) => w.type === 'allergy_conflict');
      expect(conflict).toBeDefined();
      expect(conflict?.severity).toBe('danger');
    });

    it('flags duplicate drug class when multiple systemic NSAIDs are prescribed together', () => {
      const result = PrescriptionSafetyService.checkPrescriptionSafety({
        patientAllergies: [],
        medicines: [
          {
            name: 'Ketorol DT (Ketorolac)',
            dosage: '1 tab',
            frequency: 'TDS',
            duration: '2 days',
            instructions: 'Disperse in water',
          },
          {
            name: 'Voveran 50mg (Diclofenac)',
            dosage: '1 tab',
            frequency: 'BD',
            duration: '3 days',
            instructions: 'After meals',
          },
        ],
      });

      expect(result.hasWarnings).toBe(true);
      const classWarning = result.warnings.find((w) => w.type === 'duplicate_drug_class');
      expect(classWarning).toBeDefined();
      expect(classWarning?.severity).toBe('warning');
      expect(classWarning?.clinicalRationale).toContain('gastrointestinal ulceration');
    });

    it('passes safely with no warnings for non-conflicting medicines', () => {
      const result = PrescriptionSafetyService.checkPrescriptionSafety({
        patientAllergies: ['Penicillin'],
        medicines: [
          {
            name: 'Azithromycin 500mg',
            dosage: '1 tab',
            frequency: 'OD',
            duration: '3 days',
            instructions: '1 hr before meals',
          },
          {
            name: 'Paracetamol 650mg',
            dosage: '1 tab',
            frequency: 'TDS',
            duration: '3 days',
            instructions: 'After food',
          },
        ],
      });

      expect(result.hasWarnings).toBe(false);
      expect(result.warnings.length).toBe(0);
    });
  });

  // ---------------------------------------------------------
  // 3. No-Show Prediction
  // ---------------------------------------------------------
  describe('No-Show Prediction Service', () => {
    it('scores low risk for confirmed appointments with 0 past misses and short lead time', () => {
      const result = NoShowPredictionService.predict({
        leadTimeDays: 2,
        appointmentDate: '2026-10-25',
        appointmentTime: '11:00 AM',
        pastMissedCount: 0,
        pastAttendanceRate: 1.0,
        confirmationStatus: 'Confirmed',
        channel: 'whatsapp',
      });

      expect(result.riskScore).toBeLessThan(0.35);
      expect(result.riskLevel).toBe('low');
      expect(result.riskFactors.length).toBe(0);
    });

    it('scores high risk for unconfirmed appointments with long lead time and prior no-shows', () => {
      const result = NoShowPredictionService.predict({
        leadTimeDays: 18,
        appointmentDate: '2026-11-05',
        appointmentTime: '07:30 PM',
        pastMissedCount: 3,
        pastAttendanceRate: 0.5,
        confirmationStatus: 'Pending',
        channel: 'whatsapp',
      });

      expect(result.riskScore).toBeGreaterThanOrEqual(0.55);
      expect(result.riskLevel).toBe('high');
      expect(result.riskFactors).toContain('High past no-shows (3 missed appointments)');
      expect(result.riskFactors).toContain('Long advance booking lead time (18 days)');
      expect(result.riskFactors).toContain('Reminder unconfirmed');
    });
  });

  // ---------------------------------------------------------
  // 4. Smart Reminder Timing
  // ---------------------------------------------------------
  describe('Smart Reminder Timing Service', () => {
    it('clamps quiet hours (22:00 to 07:00 IST) to 09:00 AM IST', () => {
      expect(SmartTimingService.isQuietHour(23)).toBe(true);
      expect(SmartTimingService.isQuietHour(3)).toBe(true);
      expect(SmartTimingService.isQuietHour(14)).toBe(false);

      const result = SmartTimingService.getOptimalSendHour({
        preferredReminderHour: 23, // Late night preference
      });

      expect(result.sendHour).toBe(9);
      expect(result.formattedTime).toBe('09:00 AM');
      expect(result.reasoning).toContain('outside quiet hours');
    });

    it('respects daytime explicit preference', () => {
      const result = SmartTimingService.getOptimalSendHour({
        preferredReminderHour: 16, // 4 PM
      });

      expect(result.sendHour).toBe(16);
      expect(result.formattedTime).toBe('04:00 PM');
    });

    it('derives optimal hour from past response history mode', () => {
      const result = SmartTimingService.getOptimalSendHour({
        pastResponseHours: [11, 17, 17, 17, 11], // 17 (5 PM) is mode
      });

      expect(result.sendHour).toBe(17);
      expect(result.formattedTime).toBe('05:00 PM');
      expect(result.reasoning).toContain('Derived from 5 past responses');
    });

    it('defaults to 10:00 AM IST when no history is available', () => {
      const result = SmartTimingService.getOptimalSendHour({});
      expect(result.sendHour).toBe(10);
      expect(result.formattedTime).toBe('10:00 AM');
    });
  });

  // ---------------------------------------------------------
  // 5. Grounded WhatsApp FAQ Assistant (RAG)
  // ---------------------------------------------------------
  describe('WhatsApp FAQ Assistant Service (RAG & Safety Guardrails)', () => {
    it('strictly refuses clinical symptoms and initiates staff handoff without medical advice', async () => {
      const result = await FaqAssistantService.queryFaq({
        clinicId: 'clinic_test',
        patientId: 'patient_123',
        query: 'I had my root canal done yesterday and now I have severe pain and bleeding',
        preferredLanguage: 'en',
      });

      expect(result.isClinicalHandoff).toBe(true);
      expect(result.isGrounded).toBe(false);
      expect(result.answer).toContain('clinical symptoms or discomfort');
      expect(result.answer).toContain('automated medical advice is not provided');
      expect(result.citations).toContain('Clinical Safety Protocol');
    });

    it('answers clinic timings questions with citations to clinic documents', async () => {
      const result = await FaqAssistantService.queryFaq({
        clinicId: 'clinic_test',
        patientId: 'patient_123',
        query: 'What are your clinic timings on weekdays and is Sunday open?',
        preferredLanguage: 'en',
      });

      expect(result.isClinicalHandoff).toBe(false);
      expect(result.isGrounded).toBe(true);
      expect(result.answer).toContain('09:00 AM to 08:00 PM');
      expect(result.answer).toContain('[Source: Clinic Timings & Working Hours]');
      expect(result.citations).toContain('Clinic Timings & Working Hours');
    });

    it('answers scaling and cleaning queries accurately with citation', async () => {
      const result = await FaqAssistantService.queryFaq({
        clinicId: 'clinic_test',
        patientId: 'patient_123',
        query: 'How often should I get teeth cleaning and scaling done?',
        preferredLanguage: 'en',
      });

      expect(result.isClinicalHandoff).toBe(false);
      expect(result.isGrounded).toBe(true);
      expect(result.answer).toContain('once every 6 months');
      expect(result.answer).toContain('[Source: Dental Scaling & Teeth Cleaning]');
    });

    it('refuses ungrounded queries politely and hands off to reception', async () => {
      const result = await FaqAssistantService.queryFaq({
        clinicId: 'clinic_test',
        patientId: 'patient_123',
        query: 'Can you recommend a good Italian restaurant nearby?',
        preferredLanguage: 'en',
      });

      expect(result.isClinicalHandoff).toBe(false);
      expect(result.isGrounded).toBe(false);
      expect(result.answer).toContain("don't have verified clinic information on that specific topic");
    });
  });
});
