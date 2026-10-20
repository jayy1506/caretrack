import {
  PrescriptionDocument,
  MedicineItem,
  MedicationScheduleDocument,
  MedicationScheduleItem,
  MedicationTimeWindows,
  MedicationWindow,
} from '../types/index.js';

export class MedicationScheduleService {
  public static readonly DEFAULT_TIME_WINDOWS: MedicationTimeWindows = {
    morning: '08:30 AM',
    afternoon: '01:30 PM',
    night: '08:30 PM',
  };

  /**
   * Deterministically maps medicine frequency strings to daily medication windows
   */
  public static mapFrequencyToWindows(frequencyStr: string): MedicationWindow[] {
    const clean = frequencyStr.trim().toUpperCase();

    // Specific shorthand notation
    if (clean.includes('TDS') || clean.includes('THRICE') || clean === '1-1-1' || clean.includes('3 TIMES')) {
      return ['morning', 'afternoon', 'night'];
    }
    if (clean.includes('BD') || clean.includes('TWICE') || clean === '1-0-1' || clean.includes('2 TIMES')) {
      return ['morning', 'night'];
    }
    if (clean.includes('HS') || clean.includes('BEDTIME') || clean === '0-0-1' || clean.includes('NIGHT')) {
      return ['night'];
    }
    if (clean.includes('AFTERNOON') || clean === '0-1-0') {
      return ['afternoon'];
    }
    if (clean.includes('OD') || clean.includes('ONCE') || clean === '1-0-0' || clean.includes('MORNING')) {
      return ['morning'];
    }
    if (clean.includes('QID') || clean.includes('FOUR') || clean === '1-1-1-1') {
      return ['morning', 'afternoon', 'night'];
    }

    // Default fallback to twice daily (morning & night)
    return ['morning', 'night'];
  }

  /**
   * Extracts duration in days from string or number (e.g. "5 days" -> 5)
   */
  public static parseDurationDays(durationStr: string): number {
    if (!durationStr) return 5;
    const match = durationStr.match(/\d+/);
    if (match) {
      const days = parseInt(match[0], 10);
      return days > 0 ? days : 5;
    }
    return 5;
  }

  /**
   * Add days to a YYYY-MM-DD date string
   */
  public static addDays(dateStr: string, days: number): string {
    const [y, m, d] = dateStr.split('-').map((v) => parseInt(v, 10));
    const target = new Date(y, m - 1, d);
    target.setDate(target.getDate() + days);

    const year = target.getFullYear();
    const month = String(target.getMonth() + 1).padStart(2, '0');
    const day = String(target.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  /**
   * Checks if a given time is in quiet hours (22:00 to 07:00 IST).
   * Returns adjusted safe time (e.g. "08:00 AM") if in quiet hours.
   */
  public static adjustForQuietHours(timeStr: string, quietStartHour = 22, quietEndHour = 7): string {
    const upper = timeStr.trim().toUpperCase();
    const isPM = upper.includes('PM');
    const isAM = upper.includes('AM');
    const raw = upper.replace(/(AM|PM)/g, '').trim();

    const [hStr, mStr] = raw.split(':');
    let hours = parseInt(hStr, 10) || 0;
    const minutes = parseInt(mStr, 10) || 0;

    if (isPM && hours < 12) hours += 12;
    if (isAM && hours === 12) hours = 0;

    // Check if within quiet window: >= 22 or < 7
    if (hours >= quietStartHour || hours < quietEndHour) {
      // Shift to safe morning hour 08:00 AM
      return '08:00 AM';
    }

    return timeStr;
  }

  /**
   * Generates a draft medication schedule from a verified prescription
   */
  public static generateScheduleFromPrescription(
    prescription: PrescriptionDocument,
    scheduleId: string,
    customWindows?: Partial<MedicationTimeWindows>
  ): MedicationScheduleDocument {
    const windows: MedicationTimeWindows = {
      ...this.DEFAULT_TIME_WINDOWS,
      ...customWindows,
    };

    // Ensure configured windows respect quiet hours
    windows.morning = this.adjustForQuietHours(windows.morning);
    windows.afternoon = this.adjustForQuietHours(windows.afternoon);
    windows.night = this.adjustForQuietHours(windows.night);

    let maxDuration = 1;
    const items: MedicationScheduleItem[] = (prescription.medicines || []).map((med) => {
      const duration = this.parseDurationDays(med.duration);
      if (duration > maxDuration) maxDuration = duration;

      return {
        medicineName: med.name,
        dosage: med.dosage || '1 unit',
        frequency: med.frequency || 'Twice a day',
        timing: this.mapFrequencyToWindows(med.frequency || ''),
        instructions: med.instructions || 'After food',
        durationDays: duration,
      };
    });

    const startDate = prescription.prescriptionDate || new Date().toISOString().split('T')[0];
    const endDate = this.addDays(startDate, maxDuration);

    return {
      id: scheduleId,
      clinicId: prescription.clinicId || 'default-clinic',
      patientId: prescription.patientId,
      doctorId: prescription.doctorId,
      prescriptionId: prescription.id || '',
      status: 'draft',
      startDate,
      endDate,
      timeWindows: windows,
      items,
      adherence: {
        totalReminders: 0,
        takenCount: 0,
        missedCount: 0,
        adherenceRate: 100,
      },
      doctorConfirmed: false,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
  }

  /**
   * Calculates adherence percentage (0 - 100)
   */
  public static calculateAdherence(takenCount: number, totalReminders: number): number {
    if (totalReminders <= 0) return 100;
    const rate = (takenCount / totalReminders) * 100;
    return Math.round(Math.min(100, Math.max(0, rate)) * 10) / 10;
  }
}
