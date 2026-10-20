import { FollowUpType } from '../types/index.js';

export interface FollowUpDateOptions {
  skipSundays?: boolean;
  holidays?: string[]; // Array of YYYY-MM-DD
}

export class FollowUpService {
  /**
   * Deterministically calculates follow-up date based on prescription date and follow-up type.
   * Format: YYYY-MM-DD
   */
  public static calculateFollowUpDate(
    prescriptionDateStr: string,
    followUpType: FollowUpType,
    customDateStr?: string,
    options?: FollowUpDateOptions
  ): string {
    if (followUpType === 'custom' && customDateStr) {
      return this.adjustForClinicRules(customDateStr, options);
    }

    const [y, m, d] = prescriptionDateStr.split('-').map((v) => parseInt(v, 10));
    const baseDate = new Date(y, m - 1, d);
    if (isNaN(baseDate.getTime())) {
      return this.addMonths(new Date(), 3, options);
    }

    let calculated: string;
    switch (followUpType) {
      case '15_days': {
        const target = new Date(baseDate);
        target.setDate(target.getDate() + 15);
        calculated = this.formatDate(target);
        break;
      }
      case '1_month': {
        calculated = this.addMonths(baseDate, 1);
        break;
      }
      case '3_months': {
        calculated = this.addMonths(baseDate, 3);
        break;
      }
      case '6_months': {
        calculated = this.addMonths(baseDate, 6);
        break;
      }
      default: {
        calculated = this.addMonths(baseDate, 3);
        break;
      }
    }

    return this.adjustForClinicRules(calculated, options);
  }

  /**
   * Proposes the date for the next treatment stage given interval days and clinic constraints.
   * Pure, deterministic, handles month-ends, Sundays, and clinic holidays.
   */
  public static proposeNextStageDate(
    baseDateStr: string,
    intervalDays: number,
    options?: FollowUpDateOptions
  ): string {
    const [y, m, d] = baseDateStr.split('-').map((v) => parseInt(v, 10));
    const target = new Date(y, m - 1, d);
    target.setDate(target.getDate() + intervalDays);
    const initialDateStr = this.formatDate(target);

    return this.adjustForClinicRules(initialDateStr, options);
  }

  /**
   * Advances date forward if it falls on a Sunday (when skipSundays is enabled)
   * or matches any clinic holiday.
   */
  public static adjustForClinicRules(dateStr: string, options?: FollowUpDateOptions): string {
    const skipSundays = options?.skipSundays ?? false;
    const holidays = new Set(options?.holidays || []);

    const [y, m, d] = dateStr.split('-').map((v) => parseInt(v, 10));
    const current = new Date(y, m - 1, d);

    let changed = true;
    let guard = 0;
    while (changed && guard < 30) {
      guard++;
      changed = false;
      const formatted = this.formatDate(current);

      // Check Sunday (0 = Sunday in JS Date)
      if (skipSundays && current.getDay() === 0) {
        current.setDate(current.getDate() + 1);
        changed = true;
        continue;
      }

      // Check Holiday
      if (holidays.has(formatted)) {
        current.setDate(current.getDate() + 1);
        changed = true;
        continue;
      }
    }

    return this.formatDate(current);
  }

  /**
   * Safe month addition handling end-of-month rollovers accurately
   * (e.g. Aug 31 + 6 months -> Feb 28/29, Jan 31 + 1 month -> Feb 28/29)
   */
  public static addMonths(date: Date, months: number, options?: FollowUpDateOptions): string {
    const startYear = date.getFullYear();
    const startMonth = date.getMonth();
    const startDay = date.getDate();

    const targetDate = new Date(startYear, startMonth + months, 1);
    const targetYear = targetDate.getFullYear();
    const targetMonth = targetDate.getMonth();

    // Determine the last day of target month
    const daysInTargetMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
    const safeDay = Math.min(startDay, daysInTargetMonth);

    const result = new Date(targetYear, targetMonth, safeDay);
    const formatted = this.formatDate(result);

    return this.adjustForClinicRules(formatted, options);
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
