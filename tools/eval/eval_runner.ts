import * as fs from 'fs';
import * as path from 'path';

export interface MedicineItem {
  name: string;
  dosage: string;
  frequency: string;
  duration: string;
  instructions?: string;
}

export interface ExpectedPrescription {
  medicines: MedicineItem[];
  prescriptionDate: string;
  followUpInstructions?: string;
  suggestedFollowUpType?: string;
}

export interface EvalSample {
  id: string;
  disclaimer: string;
  input: {
    simulatedText: string;
    mimeType?: string;
  };
  expected: ExpectedPrescription;
}

export interface FieldAccuracyReport {
  nameAccuracy: number;
  dosageAccuracy: number;
  frequencyAccuracy: number;
  durationAccuracy: number;
  totalExpectedMedicines: number;
  totalExtractedMedicines: number;
  matchedMedicinesCount: number;
  precision: number;
  recall: number;
  f1Score: number;
  overallAccuracy: number;
  perSampleResults: Array<{
    sampleId: string;
    expectedCount: number;
    extractedCount: number;
    fieldScores: {
      name: number;
      dosage: number;
      frequency: number;
      duration: number;
    };
  }>;
}

export class PrescriptionEvalRunner {
  /**
   * Normalizes strings for robust fuzzy comparison (lowercasing, punctuation stripping, whitespace trim).
   */
  public static normalize(str: string): string {
    return (str || '')
      .toLowerCase()
      .replace(/[^a-z0-9]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * Checks similarity / match between two field values.
   */
  public static isFieldMatch(actual: string, expected: string): boolean {
    const normActual = this.normalize(actual);
    const normExpected = this.normalize(expected);

    if (normActual === normExpected) return true;
    if (normActual.includes(normExpected) || normExpected.includes(normActual)) return true;

    // Common medical abbreviation equivalencies
    if (
      (normActual.includes('three') && normExpected.includes('tds')) ||
      (normActual.includes('tds') && normExpected.includes('three')) ||
      (normActual.includes('twice') && normExpected.includes('bd')) ||
      (normActual.includes('bd') && normExpected.includes('twice')) ||
      (normActual.includes('once') && normExpected.includes('od')) ||
      (normActual.includes('od') && normExpected.includes('once')) ||
      (normActual.includes('tab') && normExpected.includes('tablet')) ||
      (normActual.includes('cap') && normExpected.includes('capsule'))
    ) {
      return true;
    }

    return false;
  }

  /**
   * Evaluates a batch of extractions against the expected ground truth samples.
   */
  public static evaluate(
    samples: EvalSample[],
    extractions: Record<string, ExpectedPrescription>
  ): FieldAccuracyReport {
    let totalNameMatches = 0;
    let totalDosageMatches = 0;
    let totalFreqMatches = 0;
    let totalDurationMatches = 0;

    let totalExpectedMedicines = 0;
    let totalExtractedMedicines = 0;
    let matchedMedicinesCount = 0;

    const perSampleResults: FieldAccuracyReport['perSampleResults'] = [];

    for (const sample of samples) {
      const extracted = extractions[sample.id] || { medicines: [], prescriptionDate: '' };
      const expectedMeds = sample.expected.medicines;
      const extractedMeds = extracted.medicines || [];

      totalExpectedMedicines += expectedMeds.length;
      totalExtractedMedicines += extractedMeds.length;

      let sampleNameMatches = 0;
      let sampleDosageMatches = 0;
      let sampleFreqMatches = 0;
      let sampleDurationMatches = 0;

      // Track matched indices to avoid double counting
      const usedExtractedIdx = new Set<number>();

      for (const exp of expectedMeds) {
        let bestIdx = -1;
        for (let i = 0; i < extractedMeds.length; i++) {
          if (usedExtractedIdx.has(i)) continue;
          if (this.isFieldMatch(extractedMeds[i].name, exp.name)) {
            bestIdx = i;
            break;
          }
        }

        if (bestIdx !== -1) {
          usedExtractedIdx.add(bestIdx);
          matchedMedicinesCount++;
          sampleNameMatches++;
          totalNameMatches++;

          const matchMed = extractedMeds[bestIdx];
          if (this.isFieldMatch(matchMed.dosage, exp.dosage)) {
            sampleDosageMatches++;
            totalDosageMatches++;
          }
          if (this.isFieldMatch(matchMed.frequency, exp.frequency)) {
            sampleFreqMatches++;
            totalFreqMatches++;
          }
          if (this.isFieldMatch(matchMed.duration, exp.duration)) {
            sampleDurationMatches++;
            totalDurationMatches++;
          }
        }
      }

      perSampleResults.push({
        sampleId: sample.id,
        expectedCount: expectedMeds.length,
        extractedCount: extractedMeds.length,
        fieldScores: {
          name: expectedMeds.length ? sampleNameMatches / expectedMeds.length : 1,
          dosage: expectedMeds.length ? sampleDosageMatches / expectedMeds.length : 1,
          frequency: expectedMeds.length ? sampleFreqMatches / expectedMeds.length : 1,
          duration: expectedMeds.length ? sampleDurationMatches / expectedMeds.length : 1,
        },
      });
    }

    const denom = totalExpectedMedicines || 1;
    const nameAccuracy = totalNameMatches / denom;
    const dosageAccuracy = totalDosageMatches / denom;
    const frequencyAccuracy = totalFreqMatches / denom;
    const durationAccuracy = totalDurationMatches / denom;

    const precision = totalExtractedMedicines > 0 ? matchedMedicinesCount / totalExtractedMedicines : 0;
    const recall = totalExpectedMedicines > 0 ? matchedMedicinesCount / totalExpectedMedicines : 0;
    const f1Score = precision + recall > 0 ? (2 * precision * recall) / (precision + recall) : 0;
    const overallAccuracy = (nameAccuracy + dosageAccuracy + frequencyAccuracy + durationAccuracy) / 4;

    return {
      nameAccuracy,
      dosageAccuracy,
      frequencyAccuracy,
      durationAccuracy,
      totalExpectedMedicines,
      totalExtractedMedicines,
      matchedMedicinesCount,
      precision,
      recall,
      f1Score,
      overallAccuracy,
      perSampleResults,
    };
  }

  /**
   * Generates a clean Markdown evaluation report.
   */
  public static generateMarkdownReport(report: FieldAccuracyReport): string {
    const toPct = (val: number) => `${(val * 100).toFixed(1)}%`;

    return `# Prescription Extraction Evaluation Report

> **Dataset Disclaimer**: Evaluated against SYNTHETIC/SAMPLE labeled prescriptions only. No real patient data is used in automated benchmarking.

## Summary Metrics

| Metric | Score | Target | Status |
| :--- | :--- | :--- | :--- |
| **Medicine Name Accuracy** | **${toPct(report.nameAccuracy)}** | >= 90% | ${report.nameAccuracy >= 0.9 ? 'PASS' : 'WARN'} |
| **Dosage Accuracy** | **${toPct(report.dosageAccuracy)}** | >= 85% | ${report.dosageAccuracy >= 0.85 ? 'PASS' : 'WARN'} |
| **Frequency Accuracy** | **${toPct(report.frequencyAccuracy)}** | >= 85% | ${report.frequencyAccuracy >= 0.85 ? 'PASS' : 'WARN'} |
| **Duration Accuracy** | **${toPct(report.durationAccuracy)}** | >= 85% | ${report.durationAccuracy >= 0.85 ? 'PASS' : 'WARN'} |
| **Overall Accuracy** | **${toPct(report.overallAccuracy)}** | >= 85% | ${report.overallAccuracy >= 0.85 ? 'PASS' : 'WARN'} |
| **Extraction Precision** | **${toPct(report.precision)}** | >= 85% | ${report.precision >= 0.85 ? 'PASS' : 'WARN'} |
| **Extraction Recall** | **${toPct(report.recall)}** | >= 85% | ${report.recall >= 0.85 ? 'PASS' : 'WARN'} |
| **F1 Score** | **${toPct(report.f1Score)}** | >= 85% | ${report.f1Score >= 0.85 ? 'PASS' : 'WARN'} |

- **Total Expected Medicines**: ${report.totalExpectedMedicines}
- **Total Extracted Medicines**: ${report.totalExtractedMedicines}
- **Matched Medicines Count**: ${report.matchedMedicinesCount}

## Sample-by-Sample Breakdown

| Sample ID | Expected | Extracted | Name Score | Dose Score | Freq Score | Duration Score |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
${report.perSampleResults
  .map(
    (s) =>
      `| \`${s.sampleId}\` | ${s.expectedCount} | ${s.extractedCount} | ${toPct(s.fieldScores.name)} | ${toPct(
        s.fieldScores.dosage
      )} | ${toPct(s.fieldScores.frequency)} | ${toPct(s.fieldScores.duration)} |`
  )
  .join('\n')}

---
*Report generated automatically by CareTrack Prescription Evaluation Runner.*
`;
  }
}
