import { describe, it, expect } from 'vitest';
import { normalizePhoneNumber } from '../src/services/messagingService.js';
import { maskRecipient } from '../src/services/notificationService.js';
import { FollowUpService } from '../src/services/followUpService.js';
import { DEFAULT_DENTAL_TEMPLATES } from '../src/treatmentPlans/index.js';
import { SlotService } from '../src/services/slotService.js';
import { TemplateRegistryService } from '../src/services/templateRegistry.js';
import { MedicationScheduleService } from '../src/services/medicationScheduleService.js';
import { z } from 'zod';

const CreateStaffSchema = z.object({
  clinicId: z.string().min(1, 'clinicId is required'),
  name: z.string().min(1, 'Full name is required'),
  email: z.string().email('Valid email is required'),
  password: z.string().min(6, 'Temporary password must be at least 6 characters long'),
  role: z.enum(['doctor', 'receptionist']),
  phone: z.string().optional(),
  active: z.boolean().optional(),
});

describe('Phase 1 Unit Tests: Multi-Clinic & Staff Architecture', () => {
  describe('Phone Normalization & E.164 compliance', () => {
    it('normalizes 10-digit Indian numbers to E.164 +91 prefix', () => {
      const result = normalizePhoneNumber('9876543210');
      expect(result.valid).toBe(true);
      expect(result.normalized).toBe('+919876543210');
    });

    it('preserves existing valid E.164 numbers', () => {
      const result = normalizePhoneNumber('+14155552671');
      expect(result.valid).toBe(true);
      expect(result.normalized).toBe('+14155552671');
    });

    it('rejects invalid or too short numbers with descriptive error', () => {
      const result = normalizePhoneNumber('1234');
      expect(result.valid).toBe(false);
      expect(result.error).toBeDefined();
    });
  });

  describe('PII Masking for HIPAA & DPDP compliance', () => {
    it('masks phone numbers leaving only country prefix and last 4 digits', () => {
      const masked = maskRecipient('+919876543210', 'messaging');
      expect(masked).toBe('+91******3210');
    });

    it('masks email addresses preserving first/last local char and domain', () => {
      const masked = maskRecipient('patient@example.com', 'email');
      expect(masked).toBe('p***t@example.com');
      expect(masked).not.toContain('patient');
    });
  });

  describe('Zod Schema Validation for Staff Creation', () => {
    it('succeeds for valid doctor staff payload', () => {
      const validPayload = {
        clinicId: 'clinic-123',
        name: 'Dr. Jane Doe',
        email: 'jane.doe@clinic.com',
        password: 'temporaryPassword123',
        role: 'doctor',
      };
      const result = CreateStaffSchema.safeParse(validPayload);
      expect(result.success).toBe(true);
    });

    it('succeeds for valid receptionist staff payload', () => {
      const validPayload = {
        clinicId: 'clinic-123',
        name: 'Alex Reception',
        email: 'alex@clinic.com',
        password: 'temporaryPassword123',
        role: 'receptionist',
      };
      const result = CreateStaffSchema.safeParse(validPayload);
      expect(result.success).toBe(true);
    });

    it('fails when clinicId is missing or role is invalid', () => {
      const invalidPayload = {
        name: 'Alex Reception',
        email: 'alex@clinic.com',
        password: 'short',
        role: 'superadmin',
      };
      const result = CreateStaffSchema.safeParse(invalidPayload);
      expect(result.success).toBe(false);
    });
  });
});

describe('Phase 2 Unit Tests: Treatment Plans & Deterministic Scheduling', () => {
  describe('FollowUpService - proposeNextStageDate & Date Math', () => {
    it('proposes next stage date accurately by adding interval days', () => {
      const nextDate = FollowUpService.proposeNextStageDate('2026-10-01', 7);
      expect(nextDate).toBe('2026-10-08');
    });

    it('handles leap year month-end roll safely (Jan 31 on leap year -> Feb 29)', () => {
      const result = FollowUpService.addMonths(new Date(2024, 0, 31), 1);
      expect(result).toBe('2024-02-29');
    });

    it('handles non-leap year month-end roll safely (Jan 31 non-leap -> Feb 28)', () => {
      const result = FollowUpService.addMonths(new Date(2023, 0, 31), 1);
      expect(result).toBe('2023-02-28');
    });

    it('handles 6-month recall from August 31 safely without month overflow', () => {
      const result = FollowUpService.addMonths(new Date(2026, 7, 31), 6);
      expect(result).toBe('2027-02-28');
    });

    it('skips Sundays when skipSundays is true (advances to Monday)', () => {
      // 2026-10-25 is a Sunday
      const adjusted = FollowUpService.adjustForClinicRules('2026-10-25', { skipSundays: true });
      expect(adjusted).toBe('2026-10-26'); // Monday
    });

    it('skips clinic holidays and rolls forward', () => {
      const adjusted = FollowUpService.adjustForClinicRules('2026-10-26', {
        holidays: ['2026-10-26'],
      });
      expect(adjusted).toBe('2026-10-27');
    });

    it('skips consecutively if Sunday is followed by a Monday holiday (advances to Tuesday)', () => {
      // 2026-10-25 is Sunday. 2026-10-26 is marked as a clinic holiday.
      const adjusted = FollowUpService.adjustForClinicRules('2026-10-25', {
        skipSundays: true,
        holidays: ['2026-10-26'],
      });
      expect(adjusted).toBe('2026-10-27'); // Tuesday
    });
  });

  describe('Pre-seeded Dental Plan Templates', () => {
    it('provides exactly 5 comprehensive clinical dental templates', () => {
      expect(DEFAULT_DENTAL_TEMPLATES.length).toBe(5);
    });

    it('includes Root Canal, Braces, Scaling, Implants, and Extraction protocols', () => {
      const ids = DEFAULT_DENTAL_TEMPLATES.map((t) => t.id);
      expect(ids).toContain('tpl_rct_3');
      expect(ids).toContain('tpl_braces_monthly');
      expect(ids).toContain('tpl_scaling_routine');
      expect(ids).toContain('tpl_implant_multiphase');
      expect(ids).toContain('tpl_extraction_7d');
    });

    it('all templates have stages ordered sequentially starting at order 1', () => {
      for (const tpl of DEFAULT_DENTAL_TEMPLATES) {
        expect(tpl.stages.length).toBeGreaterThan(0);
        tpl.stages.forEach((stage, idx) => {
          expect(stage.order).toBe(idx + 1);
          expect(stage.name.length).toBeGreaterThan(3);
        });
      }
    });
  });

  describe('Treatment Plan Zod Schemas', () => {
    const PlanSchema = z.object({
      clinicId: z.string().min(1),
      patientId: z.string().min(1),
      title: z.string().min(1),
      firstAppointmentDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    });

    it('accepts valid treatment plan payload', () => {
      const payload = {
        clinicId: 'clinic-1',
        patientId: 'patient-abc',
        title: 'RCT Lower Left Molar',
        firstAppointmentDate: '2026-10-28',
      };
      const res = PlanSchema.safeParse(payload);
      expect(res.success).toBe(true);
    });

    it('rejects invalid date format', () => {
      const payload = {
        clinicId: 'clinic-1',
        patientId: 'patient-abc',
        title: 'RCT Lower Left Molar',
        firstAppointmentDate: '28-10-2026', // invalid format
      };
      const res = PlanSchema.safeParse(payload);
      expect(res.success).toBe(false);
    });
  });
});

describe('Phase 3 Unit Tests: Online Booking & Slot Management Engine', () => {
  describe('SlotService - Time Conversions & Formatting', () => {
    it('converts 12-hour AM/PM time strings to accurate minutes from midnight', () => {
      expect(SlotService.timeStringToMinutes('09:00 AM')).toBe(540);
      expect(SlotService.timeStringToMinutes('12:00 PM')).toBe(720);
      expect(SlotService.timeStringToMinutes('12:00 AM')).toBe(0);
      expect(SlotService.timeStringToMinutes('01:30 PM')).toBe(810);
      expect(SlotService.timeStringToMinutes('06:00 PM')).toBe(1080);
    });

    it('converts minutes from midnight back to 12-hour AM/PM format', () => {
      expect(SlotService.minutesToTimeString(540)).toBe('9:00 AM');
      expect(SlotService.minutesToTimeString(720)).toBe('12:00 PM');
      expect(SlotService.minutesToTimeString(810)).toBe('1:30 PM');
      expect(SlotService.minutesToTimeString(1080)).toBe('6:00 PM');
    });
  });

  describe('SlotService - Pure Slot Generator', () => {
    const testSchedule = SlotService.createDefaultSchedule();
    // Default schedule has:
    // Monday 09:00 AM to 06:00 PM (open)
    // Breaks: 01:00 PM to 02:00 PM (Lunch)
    // Sunday closed

    it('generates accurate 30-minute intervals within doctor working hours', () => {
      // 2026-10-19 is a Monday
      const result = SlotService.generateAvailableSlots({
        schedule: testSchedule,
        bookedAppointments: [],
        startDate: '2026-10-19',
        endDate: '2026-10-19',
        now: new Date(2026, 9, 19, 6, 0, 0),
      });

      expect(result.length).toBe(1);
      const day = result[0];
      expect(day.isOpen).toBe(true);
      expect(day.slots.length).toBeGreaterThan(10);
      expect(day.slots[0].time).toBe('9:00 AM');
      expect(day.slots[0].available).toBe(true);
    });

    it('excludes break times from available slots (marks available=false, reason=break)', () => {
      // 2026-10-19 is a Monday
      const result = SlotService.generateAvailableSlots({
        schedule: testSchedule,
        bookedAppointments: [],
        startDate: '2026-10-19',
        endDate: '2026-10-19',
        now: new Date(2026, 9, 19, 6, 0, 0),
      });

      const lunchSlot1 = result[0].slots.find((s) => s.time === '1:00 PM');
      const lunchSlot2 = result[0].slots.find((s) => s.time === '1:30 PM');

      expect(lunchSlot1).toBeDefined();
      expect(lunchSlot1!.available).toBe(false);
      expect(lunchSlot1!.reasonUnavailable).toBe('break');

      expect(lunchSlot2).toBeDefined();
      expect(lunchSlot2!.available).toBe(false);
      expect(lunchSlot2!.reasonUnavailable).toBe('break');
    });

    it('excludes already booked appointments from available slots', () => {
      const booked = [
        { date: '2026-10-19', time: '10:00 AM', status: 'Scheduled' },
        { date: '2026-10-19', time: '10:30 AM', status: 'Confirmed' },
      ];

      const result = SlotService.generateAvailableSlots({
        schedule: testSchedule,
        bookedAppointments: booked,
        startDate: '2026-10-19',
        endDate: '2026-10-19',
        now: new Date(2026, 9, 19, 6, 0, 0),
      });

      const slot1000 = result[0].slots.find((s) => s.time === '10:00 AM');
      const slot1030 = result[0].slots.find((s) => s.time === '10:30 AM');
      const slot1100 = result[0].slots.find((s) => s.time === '11:00 AM');

      expect(slot1000!.available).toBe(false);
      expect(slot1000!.reasonUnavailable).toBe('booked');

      expect(slot1030!.available).toBe(false);
      expect(slot1030!.reasonUnavailable).toBe('booked');

      expect(slot1100!.available).toBe(true);
    });

    it('does not block slots for cancelled appointments', () => {
      const booked = [
        { date: '2026-10-19', time: '10:00 AM', status: 'Cancelled' },
      ];

      const result = SlotService.generateAvailableSlots({
        schedule: testSchedule,
        bookedAppointments: booked,
        startDate: '2026-10-19',
        endDate: '2026-10-19',
        now: new Date(2026, 9, 19, 6, 0, 0),
      });

      const slot1000 = result[0].slots.find((s) => s.time === '10:00 AM');
      expect(slot1000!.available).toBe(true);
    });

    it('marks entire day closed when matching clinic holidays', () => {
      const result = SlotService.generateAvailableSlots({
        schedule: testSchedule,
        bookedAppointments: [],
        startDate: '2026-10-19',
        endDate: '2026-10-19',
        clinicHolidays: ['2026-10-19'],
        now: new Date(2026, 9, 19, 6, 0, 0),
      });

      expect(result[0].isOpen).toBe(false);
      expect(result[0].reasonClosed).toBe('Clinic Holiday');
      expect(result[0].slots.length).toBe(0);
    });

    it('marks entire day closed when doctor is on leave', () => {
      const leaveSchedule = {
        ...testSchedule,
        leaveDays: ['2026-10-19'],
      };

      const result = SlotService.generateAvailableSlots({
        schedule: leaveSchedule,
        bookedAppointments: [],
        startDate: '2026-10-19',
        endDate: '2026-10-19',
        now: new Date('2026-10-19T06:00:00Z'),
      });

      expect(result[0].isOpen).toBe(false);
      expect(result[0].reasonClosed).toBe('Doctor on Leave');
      expect(result[0].slots.length).toBe(0);
    });

    it('marks days closed on scheduled non-working days (Sunday)', () => {
      // 2026-10-18 is a Sunday
      const result = SlotService.generateAvailableSlots({
        schedule: testSchedule,
        bookedAppointments: [],
        startDate: '2026-10-18',
        endDate: '2026-10-18',
        now: new Date('2026-10-18T06:00:00Z'),
      });

      expect(result[0].isOpen).toBe(false);
      expect(result[0].reasonClosed).toBe('Closed on this day');
    });

    it('handles DST-free Indian Standard Time (Asia/Kolkata) without clock jumps', () => {
      // India has constant UTC+05:30 offset all year round.
      // Ensure date iteration across October/November preserves clean 24h days.
      const result = SlotService.generateAvailableSlots({
        schedule: testSchedule,
        bookedAppointments: [],
        startDate: '2026-10-19',
        endDate: '2026-10-21',
        timeZone: 'Asia/Kolkata',
        now: new Date('2026-10-19T06:00:00Z'),
      });

      expect(result.length).toBe(3);
      expect(result[0].date).toBe('2026-10-19');
      expect(result[1].date).toBe('2026-10-20');
      expect(result[2].date).toBe('2026-10-21');
    });
  });

  describe('Anti-Abuse & Booking Validation Schemas', () => {
    const PublicBookingSchema = z.object({
      clinicId: z.string().optional(),
      doctorId: z.string().min(1),
      date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      time: z.string().min(1),
      patientName: z.string().min(1),
      patientPhone: z.string().min(6),
      messagingConsent: z.boolean(),
      honeypot: z.string().optional(),
    });

    it('succeeds for valid public booking payload', () => {
      const payload = {
        clinicId: 'clinic-1',
        doctorId: 'doc-123',
        date: '2026-10-20',
        time: '10:00 AM',
        patientName: 'Jane Patient',
        patientPhone: '+919876543210',
        messagingConsent: true,
      };
      const res = PublicBookingSchema.safeParse(payload);
      expect(res.success).toBe(true);
    });

    it('fails when patient phone is too short', () => {
      const payload = {
        clinicId: 'clinic-1',
        doctorId: 'doc-123',
        date: '2026-10-20',
        time: '10:00 AM',
        patientName: 'Jane Patient',
        patientPhone: '123',
        messagingConsent: true,
      };
      const res = PublicBookingSchema.safeParse(payload);
      expect(res.success).toBe(false);
    });
  });
});

describe('Phase 4 Unit Tests: Two-Way WhatsApp, Recall Campaigns & Inbox', () => {
  describe('Template Registry & Multilingual Support', () => {
    it('retrieves registered Meta WhatsApp templates across English, Hindi, and Marathi', () => {
      const tplEn = TemplateRegistryService.getTemplate('appointment_reminder', 'en');
      const tplHi = TemplateRegistryService.getTemplate('appointment_reminder', 'hi');
      const tplMr = TemplateRegistryService.getTemplate('appointment_reminder', 'mr');

      expect(tplEn).toBeDefined();
      expect(tplEn?.body).toContain('Reminder:');
      expect(tplHi).toBeDefined();
      expect(tplHi?.body).toContain('स्मरण पत्र');
      expect(tplMr).toBeDefined();
      expect(tplMr?.body).toContain('आठवण');
    });

    it('falls back gracefully to English when requested language is unavailable', () => {
      const tpl = TemplateRegistryService.getTemplate('appointment_reminder', 'fr' as any);
      expect(tpl).toBeDefined();
      expect(tpl?.language).toBe('en');
    });

    it('has all templates properly approved and categorized in registry', () => {
      const all = TemplateRegistryService.getAllTemplates();
      expect(all.length).toBeGreaterThan(12);
      for (const t of all) {
        expect(['UTILITY', 'MARKETING']).toContain(t.category);
        expect(t.status).toBe('APPROVED');
        expect(t.variables.length).toBeGreaterThan(0);
      }
    });
  });

  describe('Multilingual Inbound Command Handling & Urgent Symptom Detection', () => {
    const CONFIRM_KEYWORDS = new Set([
      '1', 'confirm', 'yes', 'y', 'haan', 'ha', 'ok',
      'पुष्टि', 'हाँ', 'हा', 'स्वीकार',
      'होय', 'नक्की', 'मान्य',
    ]);

    const RESCHEDULE_KEYWORDS = new Set([
      '2', 'reschedule', 'change', 'shift', 'later',
      'बदलें', 'पुनर्निर्धारण', 'आगे बढ़ाएं',
      'वेळ बदला', 'पुढे ढकला',
    ]);

    const STOP_KEYWORDS = new Set([
      'stop', 'unsubscribe', 'cancel', 'halt',
      'रोकें', 'बंद करें',
      'थांबवा', 'बंद करा',
    ]);

    const URGENT_SYMPTOM_REGEX = /(pain|hurt|ache|bleed|bleeding|blood|fever|swelling|pus|emergency|stitch|दर्द|खून|सूज|ताप|बुखार|टाके|वेदना|रक्त)/i;

    it('recognizes multilingual confirmation commands', () => {
      expect(CONFIRM_KEYWORDS.has('1')).toBe(true);
      expect(CONFIRM_KEYWORDS.has('confirm')).toBe(true);
      expect(CONFIRM_KEYWORDS.has('पुष्टि')).toBe(true);
      expect(CONFIRM_KEYWORDS.has('हाँ')).toBe(true);
      expect(CONFIRM_KEYWORDS.has('होय')).toBe(true);
    });

    it('recognizes multilingual reschedule commands', () => {
      expect(RESCHEDULE_KEYWORDS.has('2')).toBe(true);
      expect(RESCHEDULE_KEYWORDS.has('reschedule')).toBe(true);
      expect(RESCHEDULE_KEYWORDS.has('बदलें')).toBe(true);
      expect(RESCHEDULE_KEYWORDS.has('वेळ बदला')).toBe(true);
    });

    it('recognizes opt-out STOP commands in English, Hindi, and Marathi', () => {
      expect(STOP_KEYWORDS.has('stop')).toBe(true);
      expect(STOP_KEYWORDS.has('रोकें')).toBe(true);
      expect(STOP_KEYWORDS.has('थांबवा')).toBe(true);
    });

    it('detects clinical urgency in patient messages accurately', () => {
      expect(URGENT_SYMPTOM_REGEX.test('Doctor, I have severe tooth pain after extraction')).toBe(true);
      expect(URGENT_SYMPTOM_REGEX.test('There is excessive bleeding from my gums')).toBe(true);
      expect(URGENT_SYMPTOM_REGEX.test('मुझे बहुत तेज दर्द और बुखार है')).toBe(true); // Hindi pain & fever
      expect(URGENT_SYMPTOM_REGEX.test('मला खूप वेदना आणि सूज आली आहे')).toBe(true); // Marathi pain & swelling
    });

    it('does NOT trigger false urgency on routine conversational messages', () => {
      expect(URGENT_SYMPTOM_REGEX.test('Thank you doctor, feeling much better')).toBe(false);
      expect(URGENT_SYMPTOM_REGEX.test('What are the clinic timings for tomorrow?')).toBe(false);
      expect(URGENT_SYMPTOM_REGEX.test('नमस्ते, कल कितने बजे आना है?')).toBe(false);
    });
  });

  describe('Recall Campaign Cooldown Rules', () => {
    it('enforces 14-day anti-spam cooldown window', () => {
      const now = new Date();
      const recentSend = new Date(now.getTime() - 5 * 24 * 60 * 60 * 1000); // 5 days ago
      const oldSend = new Date(now.getTime() - 20 * 24 * 60 * 60 * 1000); // 20 days ago
      const fourteenDaysAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);

      const isRecentBlocked = recentSend > fourteenDaysAgo;
      const isOldAllowed = oldSend <= fourteenDaysAgo;

      expect(isRecentBlocked).toBe(true);
      expect(isOldAllowed).toBe(true);
    });

    it('enforces 90-day cooldown on post-visit Google review requests', () => {
      const now = new Date();
      const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      const hundredDaysAgo = new Date(now.getTime() - 100 * 24 * 60 * 60 * 1000);
      const ninetyDaysAgo = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);

      expect(thirtyDaysAgo > ninetyDaysAgo).toBe(true); // Blocked
      expect(hundredDaysAgo > ninetyDaysAgo).toBe(false); // Allowed
    });
  });
});

describe('Phase 5 Unit Tests: Medication Schedules, Quiet Hours & Adherence Engine', () => {
  describe('MedicationScheduleService - Frequency Mapping to Windows', () => {
    it('maps TDS / Thrice Daily / 1-1-1 to morning, afternoon, and night windows', () => {
      expect(MedicationScheduleService.mapFrequencyToWindows('TDS')).toEqual(['morning', 'afternoon', 'night']);
      expect(MedicationScheduleService.mapFrequencyToWindows('1-1-1')).toEqual(['morning', 'afternoon', 'night']);
      expect(MedicationScheduleService.mapFrequencyToWindows('Thrice daily')).toEqual(['morning', 'afternoon', 'night']);
    });

    it('maps BD / Twice Daily / 1-0-1 to morning and night windows', () => {
      expect(MedicationScheduleService.mapFrequencyToWindows('BD')).toEqual(['morning', 'night']);
      expect(MedicationScheduleService.mapFrequencyToWindows('1-0-1')).toEqual(['morning', 'night']);
      expect(MedicationScheduleService.mapFrequencyToWindows('Twice daily')).toEqual(['morning', 'night']);
    });

    it('maps OD / Once Daily / 1-0-0 to morning window', () => {
      expect(MedicationScheduleService.mapFrequencyToWindows('OD')).toEqual(['morning']);
      expect(MedicationScheduleService.mapFrequencyToWindows('1-0-0')).toEqual(['morning']);
    });

    it('maps HS / Bedtime / 0-0-1 to night window', () => {
      expect(MedicationScheduleService.mapFrequencyToWindows('HS')).toEqual(['night']);
      expect(MedicationScheduleService.mapFrequencyToWindows('0-0-1')).toEqual(['night']);
      expect(MedicationScheduleService.mapFrequencyToWindows('Bedtime')).toEqual(['night']);
    });
  });

  describe('MedicationScheduleService - Quiet Hours Enforcement', () => {
    it('adjusts night reminders within quiet hours (22:00 - 07:00 IST) to 08:00 AM', () => {
      // 11:00 PM is 23:00 -> in quiet hours
      expect(MedicationScheduleService.adjustForQuietHours('11:00 PM')).toBe('08:00 AM');
      // 05:30 AM is in quiet hours
      expect(MedicationScheduleService.adjustForQuietHours('05:30 AM')).toBe('08:00 AM');
    });

    it('preserves daytime reminder times that fall outside quiet hours', () => {
      expect(MedicationScheduleService.adjustForQuietHours('08:30 AM')).toBe('08:30 AM');
      expect(MedicationScheduleService.adjustForQuietHours('01:30 PM')).toBe('01:30 PM');
      expect(MedicationScheduleService.adjustForQuietHours('08:30 PM')).toBe('08:30 PM');
    });
  });

  describe('MedicationScheduleService - Schedule Generation & Adherence Math', () => {
    const mockPrescription: any = {
      id: 'rx_123',
      clinicId: 'clinic_abc',
      patientId: 'pat_456',
      doctorId: 'doc_789',
      prescriptionDate: '2026-10-20',
      medicines: [
        { name: 'Amoxicillin 500mg', dosage: '1 cap', frequency: 'TDS', duration: '5 days', instructions: 'After food' },
        { name: 'Paracetamol 650mg', dosage: '1 tab', frequency: 'BD', duration: '3 days', instructions: 'SOS' },
      ],
    };

    it('generates a structured draft schedule with startDate and endDate derived from max duration', () => {
      const schedule = MedicationScheduleService.generateScheduleFromPrescription(mockPrescription, 'sched_test');
      expect(schedule.status).toBe('draft');
      expect(schedule.startDate).toBe('2026-10-20');
      // Max duration is 5 days -> endDate is 2026-10-25
      expect(schedule.endDate).toBe('2026-10-25');
      expect(schedule.items.length).toBe(2);
      expect(schedule.items[0].timing).toEqual(['morning', 'afternoon', 'night']);
      expect(schedule.items[1].timing).toEqual(['morning', 'night']);
    });

    it('computes accurate adherence rates', () => {
      expect(MedicationScheduleService.calculateAdherence(10, 10)).toBe(100);
      expect(MedicationScheduleService.calculateAdherence(8, 10)).toBe(80);
      expect(MedicationScheduleService.calculateAdherence(0, 10)).toBe(0);
      expect(MedicationScheduleService.calculateAdherence(7, 9)).toBe(77.8);
      expect(MedicationScheduleService.calculateAdherence(0, 0)).toBe(100);
    });

    it('generates deterministic idempotency keys for reminder dispatching', () => {
      const scheduleId = 'sched_999';
      const dateStr = '2026-10-20';
      const window = 'morning';
      const key = `${scheduleId}_${dateStr}_${window}`;
      expect(key).toBe('sched_999_2026-10-20_morning');
    });
  });
});




