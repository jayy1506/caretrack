import { describe, it, expect } from 'vitest';
import { normalizePhoneNumber } from '../src/services/messagingService.js';
import { maskRecipient } from '../src/services/notificationService.js';
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
