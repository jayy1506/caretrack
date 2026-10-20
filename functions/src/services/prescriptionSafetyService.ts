import { MedicineItem, PrescriptionSafetyWarning, PrescriptionSafetyCheckResult } from '../types/index.js';
import { AuditService } from './auditService.js';

interface DrugClassMapping {
  canonicalClass: string;
  genericNames: string[];
  brandNames: string[];
}

export class PrescriptionSafetyService {
  /**
   * Common dental pharmacological drug classes and brand mappings.
   */
  private static DRUG_CLASSES: DrugClassMapping[] = [
    {
      canonicalClass: 'nsaid',
      genericNames: [
        'ibuprofen',
        'diclofenac',
        'aceclofenac',
        'ketorolac',
        'naproxen',
        'aspirin',
        'acetylsalicylic',
        'etoricoxib',
        'piroxicam',
      ],
      brandNames: [
        'combiflam',
        'brufen',
        'voveran',
        'zerodol',
        'ketorol',
        'ketorol dt',
        'naprosyn',
        'ecosprin',
        'disprin',
        'hifenac',
      ],
    },
    {
      canonicalClass: 'paracetamol',
      genericNames: ['paracetamol', 'acetaminophen'],
      brandNames: ['crocin', 'dolo', 'calpol', 'combiflam', 'ultracet', 'pacimol'],
    },
    {
      canonicalClass: 'penicillin',
      genericNames: [
        'amoxicillin',
        'ampicillin',
        'clavulanic',
        'amoxicillin clavulanate',
        'penicillin',
      ],
      brandNames: ['augmentin', 'clavam', 'mox', 'novamox', 'moxikind', 'amoxyclav'],
    },
    {
      canonicalClass: 'sulfa',
      genericNames: ['sulfamethoxazole', 'trimethoprim', 'cotrimoxazole', 'sulfonamide'],
      brandNames: ['septran', 'bactrim'],
    },
    {
      canonicalClass: 'macrolide',
      genericNames: ['azithromycin', 'erythromycin', 'clarithromycin'],
      brandNames: ['azee', 'azithral', 'claribid'],
    },
    {
      canonicalClass: 'nitroimidazole',
      genericNames: ['metronidazole', 'tinidazole', 'ornidazole'],
      brandNames: ['metrogyl', 'flagyl', 'tiniba'],
    },
    {
      canonicalClass: 'fluoroquinolone',
      genericNames: ['ciprofloxacin', 'ofloxacin', 'levofloxacin', 'norfloxacin'],
      brandNames: ['ciplox', 'zanocin', 'levoflox'],
    },
  ];

  /**
   * Normalizes input text for comparison.
   */
  private static normalize(text: string): string {
    return (text || '')
      .toLowerCase()
      .replace(/[^a-z0-9]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * Identifies detected drug classes for a given medicine string.
   */
  public static detectDrugClasses(medicineName: string): string[] {
    const norm = this.normalize(medicineName);
    const classes = new Set<string>();

    for (const mapping of this.DRUG_CLASSES) {
      for (const generic of mapping.genericNames) {
        if (norm.includes(generic)) {
          classes.add(mapping.canonicalClass);
          break;
        }
      }
      for (const brand of mapping.brandNames) {
        if (norm.includes(brand)) {
          classes.add(mapping.canonicalClass);
          // Special combo brand handling
          if (brand === 'combiflam') {
            classes.add('nsaid');
            classes.add('paracetamol');
          }
          if (brand === 'ultracet') {
            classes.add('paracetamol');
          }
          break;
        }
      }
    }

    return Array.from(classes);
  }

  /**
   * Evaluates prescribed medicines against patient allergies and duplicate drug rules.
   */
  public static checkPrescriptionSafety(params: {
    medicines: MedicineItem[];
    patientAllergies?: string[];
  }): PrescriptionSafetyCheckResult {
    const warnings: PrescriptionSafetyWarning[] = [];
    const patientAllergies = (params.patientAllergies || []).map((a) => this.normalize(a)).filter(Boolean);
    const medicines = params.medicines || [];

    // 1. Allergy Conflict Checks
    for (const med of medicines) {
      const medNorm = this.normalize(med.name);
      const medClasses = this.detectDrugClasses(med.name);

      for (const allergy of patientAllergies) {
        let isConflict = false;
        let conflictReason = '';

        // Direct name match
        if (medNorm.includes(allergy) || allergy.includes(medNorm)) {
          isConflict = true;
          conflictReason = `Medicine "${med.name}" matches patient allergy "${allergy}".`;
        } else {
          // Class-based cross-reactivity match
          if (allergy.includes('penicillin') || allergy.includes('amox')) {
            if (medClasses.includes('penicillin')) {
              isConflict = true;
              conflictReason = `Patient is allergic to penicillin. "${med.name}" belongs to the penicillin class.`;
            }
          }
          if (allergy.includes('nsaid') || allergy.includes('aspirin') || allergy.includes('painkiller')) {
            if (medClasses.includes('nsaid')) {
              isConflict = true;
              conflictReason = `Patient is allergic to NSAIDs/Aspirin. "${med.name}" is an NSAID.`;
            }
          }
          if (allergy.includes('sulfa') || allergy.includes('sulfonamide')) {
            if (medClasses.includes('sulfa')) {
              isConflict = true;
              conflictReason = `Patient is allergic to sulfa compounds. "${med.name}" contains sulfonamides.`;
            }
          }
          if (allergy.includes('paracetamol') || allergy.includes('acetaminophen')) {
            if (medClasses.includes('paracetamol')) {
              isConflict = true;
              conflictReason = `Patient is allergic to paracetamol. "${med.name}" contains paracetamol.`;
            }
          }
        }

        if (isConflict) {
          warnings.push({
            type: 'allergy_conflict',
            severity: 'danger',
            medicineName: med.name,
            conflictingItem: allergy,
            message: `ALLERGY WARNING: ${conflictReason}`,
            clinicalRationale:
              'High risk of hypersensitivity, anaphylaxis, or adverse immune reaction. Recommend choosing an alternative therapeutic class.',
          });
        }
      }
    }

    // 2. Duplicate Medicine & Class Checks
    const seenNames = new Map<string, string>();
    const seenClasses = new Map<string, string>();

    for (const med of medicines) {
      const normName = this.normalize(med.name);
      const classes = this.detectDrugClasses(med.name);

      // Check exact duplicate names
      for (const [existingNorm, existingOriginal] of seenNames.entries()) {
        if (normName === existingNorm || (normName.length > 4 && existingNorm.includes(normName))) {
          warnings.push({
            type: 'duplicate_drug',
            severity: 'warning',
            medicineName: med.name,
            conflictingItem: existingOriginal,
            message: `DUPLICATE DRUG: "${med.name}" appears duplicate with "${existingOriginal}".`,
            clinicalRationale:
              'Avoid redundant prescribing of identical formulations to prevent accidental supratherapeutic dosage.',
          });
        }
      }
      seenNames.set(normName, med.name);

      // Check duplicate drug classes (especially multiple NSAIDs)
      for (const cls of classes) {
        if (seenClasses.has(cls)) {
          const conflictingMed = seenClasses.get(cls)!;
          if (cls === 'nsaid') {
            warnings.push({
              type: 'duplicate_drug_class',
              severity: 'warning',
              medicineName: med.name,
              conflictingItem: conflictingMed,
              message: `DUPLICATE CLASS: Both "${med.name}" and "${conflictingMed}" are NSAID analgesics.`,
              clinicalRationale:
                'Concomitant use of multiple systemic NSAIDs increases risk of gastrointestinal ulceration and nephrotoxicity without synergistic analgesia.',
            });
          } else if (cls === 'penicillin') {
            warnings.push({
              type: 'duplicate_drug_class',
              severity: 'warning',
              medicineName: med.name,
              conflictingItem: conflictingMed,
              message: `DUPLICATE ANTIBIOTIC: Both "${med.name}" and "${conflictingMed}" contain penicillin-class antibiotics.`,
              clinicalRationale:
                'Avoid dual coverage with identical antibiotic mechanisms unless specifically indicated.',
            });
          }
        } else {
          seenClasses.set(cls, med.name);
        }
      }
    }

    return {
      hasWarnings: warnings.length > 0,
      warnings,
      patientAllergiesChecked: patientAllergies,
    };
  }

  /**
   * Logs a doctor override when a prescription is confirmed despite active safety warnings.
   */
  public static async logDoctorOverride(params: {
    clinicId: string;
    doctorId: string;
    patientId: string;
    prescriptionId: string;
    warningCount: number;
    warningTypes: string[];
    overrideReason?: string;
  }): Promise<void> {
    await AuditService.log({
      clinicId: params.clinicId,
      userId: params.doctorId,
      action: 'PRESCRIPTION_SAFETY_OVERRIDDEN',
      entityType: 'prescription',
      entityId: params.prescriptionId,
      details: {
        patientId: params.patientId,
        warningCount: params.warningCount,
        warningTypes: params.warningTypes,
        overrideReason: params.overrideReason || 'Doctor clinical judgement override',
      },
    });
  }
}
