import { FollowUpType } from '../types/index.js';

export class FollowUpService {
  /**
   * Deterministically calculates follow-up date based on prescription date and follow-up type.
   * Format: YYYY-MM-DD
   */
  public static calculateFollowUpDate(
    prescriptionDateStr: string,
    followUpType: FollowUpType,
    customDateStr?: string
  ): string {
    if (followUpType === 'custom' && customDateStr) {
      return customDateStr;
    }

    const baseDate = new Date(prescriptionDateStr);
    if (isNaN(baseDate.getTime())) {
      // Fallback to today if invalid
      return this.addMonths(new Date(), 3);
    }

    switch (followUpType) {
      case '15_days': {
        const d = new Date(baseDate);
        d.setDate(d.getDate() + 15);
        return this.formatDate(d);
      }
      case '1_month': {
        return this.addMonths(baseDate, 1);
      }
      case '3_months': {
        return this.addMonths(baseDate, 3);
      }
      case '6_months': {
        return this.addMonths(baseDate, 6);
      }
      default: {
        return this.addMonths(baseDate, 3);
      }
    }
  }

  /**
   * Safe month addition handling end-of-month rollovers accurately
   */
  private static addMonths(date: Date, months: number): string {
    const d = new Date(date);
    const targetMonth = d.getMonth() + months;
    const targetYear = d.getFullYear() + Math.floor(targetMonth / 12);
    const monthRemainder = ((targetMonth % 12) + 12) % 12;
    
    // Check day overflow
    const day = d.getDate();
    const daysInTargetMonth = new Date(targetYear, monthRemainder + 1, 0).getDate();
    const safeDay = Math.min(day, daysInTargetMonth);

    const result = new Date(targetYear, monthRemainder, safeDay);
    return this.formatDate(result);
  }

  public static formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  /**
   * Parse appointment date (YYYY-MM-DD) and time (HH:mm or hh:mm AM/PM) into standard Date object
   */
  public static parseAppointmentDateTime(dateStr: string, timeStr: string): Date {
    const cleanDate = dateStr.trim();
    let hours = 10;
    let minutes = 0;

    const timeUpper = timeStr.trim().toUpperCase();
    const isPM = timeUpper.includes('PM');
    const isAM = timeUpper.includes('AM');

    const cleanTime = timeUpper.replace(/(AM|PM)/g, '').trim();
    const parts = cleanTime.split(':');
    if (parts.length >= 2) {
      hours = parseInt(parts[0], 10) || 0;
      minutes = parseInt(parts[1], 10) || 0;

      if (isPM && hours < 12) {
        hours += 12;
      } else if (isAM && hours === 12) {
        hours = 0;
      }
    }

    const [y, m, d] = cleanDate.split('-').map((v) => parseInt(v, 10));
    return new Date(y, m - 1, d, hours, minutes, 0, 0);
  }
}
