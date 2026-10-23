// Date mathematics utilities: month-end safe, leap-year aware, quiet hours, and clinic holiday skipping

/**
 * Checks if the current time falls within Indian quiet hours (22:00 to 07:00 IST).
 * 22:00 IST = 16:30 UTC. 07:00 IST = 01:30 UTC.
 */
export function isQuietHours(date: Date = new Date(), timezone = "Asia/Kolkata"): boolean {
  // Convert date to hour in the target timezone
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    hour: "numeric",
    hour12: false,
  });
  const hour = parseInt(formatter.format(date), 10);
  return hour >= 22 || hour < 7;
}

/**
 * Month-end safe addition of months to a Date.
 * Example: Jan 31 + 1 month = Feb 28 (or Feb 29 in leap year).
 */
export function addMonthsSafe(date: Date, months: number): Date {
  const year = date.getUTCFullYear();
  const month = date.getUTCMonth();
  const day = date.getUTCDate();

  const targetMonth = month + months;
  const targetYear = year + Math.floor(targetMonth / 12);
  const normalizedMonth = ((targetMonth % 12) + 12) % 12;

  // Days in target month
  const daysInTargetMonth = new Date(Date.UTC(targetYear, normalizedMonth + 1, 0)).getUTCDate();
  const safeDay = Math.min(day, daysInTargetMonth);

  return new Date(Date.UTC(
    targetYear,
    normalizedMonth,
    safeDay,
    date.getUTCHours(),
    date.getUTCMinutes(),
    date.getUTCSeconds()
  ));
}

/**
 * Adds interval in days from previous date, safely skipping clinic holidays and optionally Sundays.
 */
export function calculateNextStageDate(
  startDate: Date,
  intervalDays: number,
  holidays: string[] = [], // Array of 'YYYY-MM-DD'
  skipSundays = true
): Date {
  const result = new Date(startDate.getTime());
  let daysAdded = 0;

  // Add the base interval first
  result.setUTCDate(result.getUTCDate() + intervalDays);

  // If the target falls on a holiday or Sunday, roll forward to the next business day
  const holidaySet = new Set(holidays);

  while (true) {
    const isoDate = result.toISOString().split("T")[0];
    const dayOfWeek = result.getUTCDay(); // 0 is Sunday

    const isSunday = skipSundays && dayOfWeek === 0;
    const isHoliday = holidaySet.has(isoDate);

    if (!isSunday && !isHoliday) {
      break;
    }

    // Roll forward 1 day
    result.setUTCDate(result.getUTCDate() + 1);
  }

  return result;
}

/**
 * Checks if a year is a leap year.
 */
export function isLeapYear(year: number): boolean {
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
}
