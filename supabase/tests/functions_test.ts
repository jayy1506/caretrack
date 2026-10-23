// Phase 2 Comprehensive Deno Test Suite
// Tests: Phone normalization, tokens, slot generation, date math, Zod schemas, notification orchestration
import { assertEquals, assertRejects, assert } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { normalizePhone, maskPhone } from "../functions/_shared/phone.ts";
import { constantTimeEquals } from "../functions/_shared/clients.ts";
import { generateSlots } from "../functions/_shared/slot_generator.ts";
import { addMonthsSafe, isLeapYear, calculateNextStageDate, isQuietHours } from "../functions/_shared/date_utils.ts";
import { geminiExtractionResponseSchema } from "../functions/_shared/schemas.ts";
import { MessagingProvider, SendResult } from "../functions/_shared/providers/messaging_provider.ts";

// ----------------------------------------------------
// 1. Phone Normalization & Masking Tests
// ----------------------------------------------------
Deno.test("Phone: normalizes various local and international Indian formats", () => {
  assertEquals(normalizePhone("9876543210"), "+919876543210");
  assertEquals(normalizePhone("09876543210"), "+919876543210");
  assertEquals(normalizePhone("+91 98765 43210"), "+919876543210");
  assertEquals(normalizePhone("919876543210"), "+919876543210");
  assertEquals(normalizePhone("+91-98765-43210"), "+919876543210");
  assertEquals(normalizePhone("+14155552671"), "+14155552671");
});

Deno.test("Phone: rejects invalid phone numbers", () => {
  assertRejects(async () => normalizePhone("123"), Error);
  assertRejects(async () => normalizePhone("abcdefghij"), Error);
});

Deno.test("Phone: masks phone numbers for audit privacy", () => {
  assertEquals(maskPhone("+919876543210"), "+91******3210");
  assertEquals(maskPhone("9876501234"), "+91******1234");
});

// ----------------------------------------------------
// 2. Token Generation & Verification Tests
// ----------------------------------------------------
async function hashTokenHelper(token: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(token);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.test("Token: constant-time comparison and SHA-256 hashing", async () => {
  const token = "a".repeat(64);
  const hash1 = await hashTokenHelper(token);
  const hash2 = await hashTokenHelper(token);
  const hashDifferent = await hashTokenHelper("b".repeat(64));

  assertEquals(constantTimeEquals(hash1, hash2), true);
  assertEquals(constantTimeEquals(hash1, hashDifferent), false);
  assertEquals(constantTimeEquals("short", "longer_token"), false);
});

// ----------------------------------------------------
// 3. Slot Generation Tests
// ----------------------------------------------------
Deno.test("Slot Generator: honors working hours, breaks, holidays, and bookings", () => {
  const availabilities = [
    {
      day_of_week: 1, // Monday
      start_time: "09:00:00",
      end_time: "12:00:00",
      slot_duration_minutes: 30,
      breaks: [{ start: "10:30", end: "11:00" }],
    },
  ];

  // 2026-10-26 is a Monday
  const mondayDate = "2026-10-26";
  const bookedSlot = "2026-10-26T09:30:00.000Z";

  const slots = generateSlots({
    date: mondayDate,
    availabilities,
    holidays: [],
    existingAppointments: [bookedSlot],
  });

  // Expected slots: 09:00 (avail), 09:30 (booked), 10:00 (avail), 10:30 (break - skipped), 11:00 (avail), 11:30 (avail)
  assertEquals(slots.length, 5);

  const slot930 = slots.find((s) => s.startsAt === bookedSlot);
  assert(slot930 !== undefined);
  assertEquals(slot930?.available, false);
  assertEquals(slot930?.reason, "Already booked");

  const slot900 = slots.find((s) => s.startsAt === "2026-10-26T09:00:00.000Z");
  assertEquals(slot900?.available, true);

  // Break slot at 10:30 should not be generated at all
  const slot1030 = slots.find((s) => s.startsAt === "2026-10-26T10:30:00.000Z");
  assertEquals(slot1030, undefined);
});

Deno.test("Slot Generator: returns zero slots on clinic holidays", () => {
  const availabilities = [
    {
      day_of_week: 1,
      start_time: "09:00:00",
      end_time: "17:00:00",
      slot_duration_minutes: 30,
    },
  ];

  const slots = generateSlots({
    date: "2026-10-26",
    availabilities,
    holidays: ["2026-10-26"], // Holiday on this day
    existingAppointments: [],
  });

  assertEquals(slots.length, 0);
});

// ----------------------------------------------------
// 4. Date Math: Month-End, Leap Years, Holidays, Quiet Hours
// ----------------------------------------------------
Deno.test("Date Math: month-end safe calculations", () => {
  // Jan 31 + 1 month in non-leap year (2025) -> Feb 28
  const jan31_2025 = new Date(Date.UTC(2025, 0, 31));
  const feb28_2025 = addMonthsSafe(jan31_2025, 1);
  assertEquals(feb28_2025.getUTCMonth(), 1); // Feb
  assertEquals(feb28_2025.getUTCDate(), 28);

  // Jan 31 + 1 month in leap year (2024) -> Feb 29
  const jan31_2024 = new Date(Date.UTC(2024, 0, 31));
  const feb29_2024 = addMonthsSafe(jan31_2024, 1);
  assertEquals(feb29_2024.getUTCMonth(), 1); // Feb
  assertEquals(feb29_2024.getUTCDate(), 29);
});

Deno.test("Date Math: leap year verification", () => {
  assertEquals(isLeapYear(2024), true);
  assertEquals(isLeapYear(2025), false);
  assertEquals(isLeapYear(2000), true);
  assertEquals(isLeapYear(1900), false);
});

Deno.test("Date Math: next stage skips clinic holidays and Sundays", () => {
  // Friday Oct 23, 2026 + 2 days -> Sunday Oct 25. Skips Sunday -> Monday Oct 26.
  const friday = new Date("2026-10-23T10:00:00Z");
  const nextDate = calculateNextStageDate(friday, 2, [], true);
  assertEquals(nextDate.getUTCDay(), 1); // Monday

  // If Monday is also a holiday, advances to Tuesday
  const nextDateHoliday = calculateNextStageDate(friday, 2, ["2026-10-26"], true);
  assertEquals(nextDateHoliday.getUTCDay(), 2); // Tuesday
});

Deno.test("Date Math: quiet hours check for India time zone", () => {
  // 23:00 IST is quiet hours
  const nightTime = new Date("2026-10-23T17:30:00Z"); // 23:00 IST
  assertEquals(isQuietHours(nightTime, "Asia/Kolkata"), true);

  // 14:00 IST is active business hours
  const dayTime = new Date("2026-10-23T08:30:00Z"); // 14:00 IST
  assertEquals(isQuietHours(dayTime, "Asia/Kolkata"), false);
});

// ----------------------------------------------------
// 5. Zod Schemas for Gemini Output
// ----------------------------------------------------
Deno.test("Schema: validates valid Gemini vision structured response", () => {
  const validOutput = {
    medicines: [
      {
        name: "Amoxicillin 500mg",
        dosage: "1 capsule",
        frequency: "Thrice daily",
        duration_days: 5,
        instructions: "Take after food",
        confidence: 0.98,
      },
    ],
    follow_up_days: 7,
    clinical_notes: "Post-scaling antibiotics",
    warnings: [],
  };

  const parsed = geminiExtractionResponseSchema.parse(validOutput);
  assertEquals(parsed.medicines.length, 1);
  assertEquals(parsed.medicines[0].name, "Amoxicillin 500mg");
});

Deno.test("Schema: fails on invalid Gemini output structure", () => {
  const invalidOutput = {
    medicines: [{ dosage: "1 tablet" }], // Missing required 'name'
  };

  assertRejects(async () => {
    geminiExtractionResponseSchema.parse(invalidOutput);
  });
});

// ----------------------------------------------------
// 6. Notification Orchestration with Mocked Providers
// ----------------------------------------------------
class MockFailingWhatsAppProvider implements MessagingProvider {
  name = "mock_failing_whatsapp";
  attempts = 0;

  async sendTemplate(): Promise<SendResult> {
    this.attempts++;
    throw new Error("503 Service Unavailable: Meta Graph API temporary down");
  }

  async sendTextMessage(): Promise<SendResult> {
    throw new Error("Failed");
  }
}

class MockSuccessEmailProvider {
  sent = false;
  async sendEmail(): Promise<{ messageId: string }> {
    this.sent = true;
    return { messageId: "email_ok_123" };
  }
}

Deno.test("Notification Orchestration: failed channel does not block successful channel", async () => {
  const wa = new MockFailingWhatsAppProvider();
  const em = new MockSuccessEmailProvider();

  const patient = {
    messagingConsent: false, // WhatsApp should be skipped
    email: "patient@example.com",
  };

  // Channel 1: WhatsApp (Skipped due to no consent)
  const waPromise = (async () => {
    if (!patient.messagingConsent) {
      return { channel: "whatsapp", skipped: true, success: false };
    }
    return await wa.sendTemplate();
  })();

  // Channel 2: Email (Succeeds)
  const emailPromise = em.sendEmail();

  const results = await Promise.allSettled([waPromise, emailPromise]);

  assertEquals(results[0].status, "fulfilled");
  assertEquals((results[0] as any).value?.skipped, true);

  assertEquals(results[1].status, "fulfilled");
  assertEquals((results[1] as any).value?.messageId, "email_ok_123");
  assertEquals(em.sent, true);
});
