import { DoctorSchedule, DayAvailability, ScheduleBreak } from '../types/index.js';

export interface GeneratedSlot {
  time: string; // e.g. "10:00 AM"
  startMinutes: number;
  available: boolean;
  reasonUnavailable?: 'booked' | 'break' | 'past' | 'leave' | 'holiday';
}

export interface DaySlots {
  date: string; // YYYY-MM-DD
  dayName: string;
  isOpen: boolean;
  reasonClosed?: string;
  slots: GeneratedSlot[];
}

export interface SlotGeneratorOptions {
  schedule: DoctorSchedule;
  bookedAppointments: Array<{ date: string; time: string; status: string }>;
  startDate: string; // YYYY-MM-DD
  endDate: string; // YYYY-MM-DD
  clinicHolidays?: string[]; // Array of YYYY-MM-DD
  timeZone?: string; // default "Asia/Kolkata"
  now?: Date; // For testing or current time check
}

export class SlotService {
  public static readonly DEFAULT_TIMEZONE = 'Asia/Kolkata';

  /**
   * Convert time string (e.g. "14:30", "09:00", "02:30 PM", "9:00 AM") to minutes from midnight
   */
  public static timeStringToMinutes(timeStr: string): number {
    const clean = timeStr.trim().toUpperCase();
    const isPM = clean.includes('PM');
    const isAM = clean.includes('AM');
    const rawTime = clean.replace(/(AM|PM)/g, '').trim();

    const [hStr, mStr] = rawTime.split(':');
    let hours = parseInt(hStr, 10) || 0;
    const minutes = parseInt(mStr, 10) || 0;

    if (isPM && hours < 12) {
      hours += 12;
    } else if (isAM && hours === 12) {
      hours = 0;
    }

    return hours * 60 + minutes;
  }

  /**
   * Convert minutes from midnight to standard 12-hour formatted time (e.g. "10:00 AM")
   */
  public static minutesToTimeString(minutesFromMidnight: number): string {
    const hours24 = Math.floor(minutesFromMidnight / 60) % 24;
    const minutes = minutesFromMidnight % 60;

    const period = hours24 >= 12 ? 'PM' : 'AM';
    let hours12 = hours24 % 12;
    if (hours12 === 0) hours12 = 12;

    const formattedMinutes = minutes.toString().padStart(2, '0');
    return `${hours12}:${formattedMinutes} ${period}`;
  }

  /**
   * Normalize an appointment time string to minutes for comparison
   */
  public static normalizeTime(timeStr: string): number {
    return this.timeStringToMinutes(timeStr);
  }

  /**
   * Formats a Date object to YYYY-MM-DD
   */
  public static formatDate(d: Date): string {
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  /**
   * Get weekday name in lowercase ('sunday', 'monday', etc.)
   */
  public static getDayName(d: Date): string {
    const dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    return dayNames[d.getDay()];
  }

  /**
   * Pure slot generator function.
   * Returns list of free and unavailable slots for a date range.
   */
  public static generateAvailableSlots(options: SlotGeneratorOptions): DaySlots[] {
    const {
      schedule,
      bookedAppointments,
      startDate,
      endDate,
      clinicHolidays = [],
      timeZone = this.DEFAULT_TIMEZONE,
      now = new Date(),
    } = options;

    const results: DaySlots[] = [];
    const holidaysSet = new Set(clinicHolidays);
    const leaveDaysSet = new Set(schedule.leaveDays || []);

    // Build active booked slots map: date -> Set of startMinutes
    const bookedByDate = new Map<string, Set<number>>();
    for (const appt of bookedAppointments) {
      const statusLower = (appt.status || '').toLowerCase();
      // Only active/pending appointments block slots
      if (statusLower === 'cancelled') continue;

      const dateKey = appt.date;
      if (!bookedByDate.has(dateKey)) {
        bookedByDate.set(dateKey, new Set<number>());
      }
      const slotMins = this.timeStringToMinutes(appt.time);
      bookedByDate.get(dateKey)!.add(slotMins);
    }

    // Convert breaks to minute intervals
    const breaksMinutes: Array<{ start: number; end: number }> = (schedule.breaks || []).map((b) => ({
      start: this.timeStringToMinutes(b.start),
      end: this.timeStringToMinutes(b.end),
    }));

    const slotDuration = schedule.slotDurationMinutes > 0 ? schedule.slotDurationMinutes : 30;

    // Date iteration (inclusive from startDate to endDate)
    const [startY, startM, startD] = startDate.split('-').map((v) => parseInt(v, 10));
    const [endY, endM, endD] = endDate.split('-').map((v) => parseInt(v, 10));

    const current = new Date(startY, startM - 1, startD);
    const end = new Date(endY, endM - 1, endD);

    const todayDateStr = this.formatDate(now);
    const nowMinutes = now.getHours() * 60 + now.getMinutes();

    let guard = 0;
    while (current <= end && guard < 60) {
      guard++;
      const dateStr = this.formatDate(current);
      const dayName = this.getDayName(current);

      // 1. Check clinic holiday
      if (holidaysSet.has(dateStr)) {
        results.push({
          date: dateStr,
          dayName,
          isOpen: false,
          reasonClosed: 'Clinic Holiday',
          slots: [],
        });
        current.setDate(current.getDate() + 1);
        continue;
      }

      // 2. Check doctor leave
      if (leaveDaysSet.has(dateStr)) {
        results.push({
          date: dateStr,
          dayName,
          isOpen: false,
          reasonClosed: 'Doctor on Leave',
          slots: [],
        });
        current.setDate(current.getDate() + 1);
        continue;
      }

      // 3. Check weekly working hours for this day
      const daySchedule: DayAvailability | undefined = schedule.weeklyHours?.[dayName];
      if (!daySchedule || !daySchedule.isOpen) {
        results.push({
          date: dateStr,
          dayName,
          isOpen: false,
          reasonClosed: 'Closed on this day',
          slots: [],
        });
        current.setDate(current.getDate() + 1);
        continue;
      }

      const openMinutes = this.timeStringToMinutes(daySchedule.start);
      const closeMinutes = this.timeStringToMinutes(daySchedule.end);

      const daySlots: GeneratedSlot[] = [];
      const bookedSet = bookedByDate.get(dateStr) || new Set<number>();

      // Generate slots in increments of slotDuration
      for (let m = openMinutes; m + slotDuration <= closeMinutes; m += slotDuration) {
        const slotEnd = m + slotDuration;
        const timeLabel = this.minutesToTimeString(m);

        // Check if overlaps with any break
        const isInBreak = breaksMinutes.some((b) => m < b.end && slotEnd > b.start);
        if (isInBreak) {
          daySlots.push({
            time: timeLabel,
            startMinutes: m,
            available: false,
            reasonUnavailable: 'break',
          });
          continue;
        }

        // Check if already booked
        if (bookedSet.has(m)) {
          daySlots.push({
            time: timeLabel,
            startMinutes: m,
            available: false,
            reasonUnavailable: 'booked',
          });
          continue;
        }

        // Check if past time today (with 10-minute buffer)
        if (dateStr === todayDateStr && m <= nowMinutes + 10) {
          daySlots.push({
            time: timeLabel,
            startMinutes: m,
            available: false,
            reasonUnavailable: 'past',
          });
          continue;
        }

        // Slot is free and available
        daySlots.push({
          time: timeLabel,
          startMinutes: m,
          available: true,
        });
      }

      results.push({
        date: dateStr,
        dayName,
        isOpen: true,
        slots: daySlots,
      });

      current.setDate(current.getDate() + 1);
    }

    return results;
  }

  /**
   * Helper to build a standard default schedule for doctors
   */
  public static createDefaultSchedule(): DoctorSchedule {
    const defaultHours: DayAvailability = {
      start: '09:00 AM',
      end: '06:00 PM',
      isOpen: true,
    };

    return {
      weeklyHours: {
        monday: { ...defaultHours },
        tuesday: { ...defaultHours },
        wednesday: { ...defaultHours },
        thursday: { ...defaultHours },
        friday: { ...defaultHours },
        saturday: { start: '09:00 AM', end: '02:00 PM', isOpen: true },
        sunday: { start: '10:00 AM', end: '02:00 PM', isOpen: false },
      },
      breaks: [
        {
          start: '01:00 PM',
          end: '02:00 PM',
          name: 'Lunch Break',
        },
      ],
      slotDurationMinutes: 30,
      leaveDays: [],
    };
  }
}
