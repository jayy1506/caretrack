// Pure, deterministic slot generator honoring working hours, breaks, holidays, leave, and booked slots

export interface DoctorAvailability {
  day_of_week?: number | null;
  start_time: string; // "09:00:00"
  end_time: string;   // "18:00:00"
  slot_duration_minutes: number;
  breaks?: Array<{ start: string; end: string }>;
  is_leave?: boolean;
  specific_date?: string | null;
}

export interface SlotGenerationParams {
  date: string; // "YYYY-MM-DD"
  timezone?: string;
  availabilities: DoctorAvailability[];
  holidays: string[]; // ["YYYY-MM-DD"]
  existingAppointments: string[]; // Array of ISO timestamps ["2026-10-24T09:30:00.000Z"]
}

export interface TimeSlot {
  startsAt: string; // ISO-8601
  timeLabel: string; // "09:30 AM"
  available: boolean;
  reason?: string;
}

export function generateSlots(params: SlotGenerationParams): TimeSlot[] {
  const { date, holidays, availabilities, existingAppointments } = params;

  // 1. Check if date is a clinic holiday
  if (holidays.includes(date)) {
    return [];
  }

  // 2. Parse day of week for target date (UTC)
  const targetDateObj = new Date(`${date}T00:00:00Z`);
  const dayOfWeek = targetDateObj.getUTCDay(); // 0 = Sunday, 6 = Saturday

  // 3. Find matching availability schedule
  // Check for specific date leave or override first
  const specificLeave = availabilities.find(
    (a) => a.specific_date === date && a.is_leave
  );
  if (specificLeave) {
    return [];
  }

  const schedule = availabilities.find(
    (a) => a.day_of_week === dayOfWeek && !a.is_leave
  );
  if (!schedule) {
    return []; // Doctor does not work on this day
  }

  const [startHour, startMin] = schedule.start_time.split(":").map(Number);
  const [endHour, endMin] = schedule.end_time.split(":").map(Number);
  const duration = schedule.slot_duration_minutes || 30;

  const startTotalMinutes = startHour * 60 + startMin;
  const endTotalMinutes = endHour * 60 + endMin;

  // Parse breaks into minute intervals
  const breakIntervals = (schedule.breaks || []).map((b) => {
    const [bStartH, bStartM] = b.start.split(":").map(Number);
    const [bEndH, bEndM] = b.end.split(":").map(Number);
    return {
      start: bStartH * 60 + bStartM,
      end: bEndH * 60 + bEndM,
    };
  });

  // Pre-process existing appointment times into Set of minutes from midnight
  const bookedIsoSet = new Set(existingAppointments.map((iso) => new Date(iso).toISOString()));

  const slots: TimeSlot[] = [];

  for (let min = startTotalMinutes; min + duration <= endTotalMinutes; min += duration) {
    // Check if slot overlaps with any break
    const slotEnd = min + duration;
    const overlapsBreak = breakIntervals.some(
      (b) => Math.max(min, b.start) < Math.min(slotEnd, b.end)
    );

    if (overlapsBreak) {
      continue; // Skip break slots
    }

    const slotH = Math.floor(min / 60);
    const slotM = min % 60;

    const slotDate = new Date(`${date}T00:00:00Z`);
    slotDate.setUTCHours(slotH, slotM, 0, 0);
    const isoString = slotDate.toISOString();

    const isBooked = bookedIsoSet.has(isoString);

    const period = slotH >= 12 ? "PM" : "AM";
    const displayH = slotH % 12 === 0 ? 12 : slotH % 12;
    const displayM = slotM.toString().padStart(2, "0");
    const label = `${displayH}:${displayM} ${period}`;

    slots.push({
      startsAt: isoString,
      timeLabel: label,
      available: !isBooked,
      ...(isBooked ? { reason: "Already booked" } : {}),
    });
  }

  return slots;
}
