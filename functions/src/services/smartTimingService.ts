import { PatientDocument } from '../types/index.js';

export interface SmartTimingResult {
  sendHour: number; // 8 to 21 in Asia/Kolkata
  formattedTime: string; // e.g. "10:00 AM"
  reasoning: string;
}

export class SmartTimingService {
  public static readonly QUIET_HOURS_START = 22; // 22:00 (10 PM)
  public static readonly QUIET_HOURS_END = 7;    // 07:00 (7 AM)
  public static readonly DEFAULT_SEND_HOUR = 10; // 10:00 AM IST

  /**
   * Determines if a given hour (0-23) falls within quiet hours.
   */
  public static isQuietHour(hour: number): boolean {
    return hour >= this.QUIET_HOURS_START || hour <= this.QUIET_HOURS_END;
  }

  /**
   * Clamps an hour into the allowed messaging window (08:00 to 21:00).
   */
  public static clampToAllowedWindow(hour: number): number {
    if (hour >= this.QUIET_HOURS_START || hour < 8) {
      return 9; // Shift late night / early morning to 9:00 AM
    }
    if (hour > 21) {
      return 20; // Shift to 8:00 PM
    }
    return hour;
  }

  /**
   * Computes the most frequent hour (mode) from past response hours.
   */
  public static calculatePreferredHourFromHistory(pastHours: number[]): number | null {
    if (!pastHours || pastHours.length === 0) return null;

    const freqMap = new Map<number, number>();
    for (const h of pastHours) {
      freqMap.set(h, (freqMap.get(h) || 0) + 1);
    }

    let bestHour = pastHours[0];
    let maxCount = 0;
    for (const [h, count] of freqMap.entries()) {
      if (count > maxCount) {
        maxCount = count;
        bestHour = h;
      }
    }

    return bestHour;
  }

  /**
   * Determines optimal reminder hour for a patient.
   */
  public static getOptimalSendHour(patient?: Partial<PatientDocument>): SmartTimingResult {
    // 1. Explicit patient preference
    if (
      patient?.preferredReminderHour !== undefined &&
      patient.preferredReminderHour !== null &&
      !isNaN(patient.preferredReminderHour)
    ) {
      const explicitHour = patient.preferredReminderHour;
      if (this.isQuietHour(explicitHour)) {
        const clamped = this.clampToAllowedWindow(explicitHour);
        return {
          sendHour: clamped,
          formattedTime: this.formatHour(clamped),
          reasoning: `Adjusted explicit preference (${this.formatHour(explicitHour)}) outside quiet hours to ${this.formatHour(clamped)}.`,
        };
      }
      return {
        sendHour: explicitHour,
        formattedTime: this.formatHour(explicitHour),
        reasoning: `Using explicit patient preferred hour (${this.formatHour(explicitHour)}).`,
      };
    }

    // 2. Behavioral response history
    const historyHours = patient?.pastResponseHours || [];
    if (historyHours.length >= 2) {
      const modalHour = this.calculatePreferredHourFromHistory(historyHours);
      if (modalHour !== null) {
        const clamped = this.clampToAllowedWindow(modalHour);
        return {
          sendHour: clamped,
          formattedTime: this.formatHour(clamped),
          reasoning: `Derived from ${historyHours.length} past responses (modal response hour: ${this.formatHour(modalHour)}).`,
        };
      }
    }

    // 3. Default optimal baseline
    return {
      sendHour: this.DEFAULT_SEND_HOUR,
      formattedTime: this.formatHour(this.DEFAULT_SEND_HOUR),
      reasoning: 'Default clinic morning window (10:00 AM) due to insufficient history.',
    };
  }

  /**
   * Converts 24-hour integer into 12-hour formatted string (e.g. 10 -> "10:00 AM").
   */
  public static formatHour(hour: number): string {
    const period = hour >= 12 ? 'PM' : 'AM';
    const displayHour = hour % 12 === 0 ? 12 : hour % 12;
    return `${displayHour.toString().padStart(2, '0')}:00 ${period}`;
  }

  /**
   * Calculates IST hour from a JavaScript Date.
   */
  public static getIstHour(date: Date): number {
    const istTime = new Date(date.getTime() + 5.5 * 60 * 60 * 1000);
    return istTime.getUTCHours();
  }
}
