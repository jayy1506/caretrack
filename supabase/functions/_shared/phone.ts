// Phone number normalization and masking helpers

/**
 * Normalizes an Indian or international phone number to strict E.164.
 * Default country is India (+91).
 * Supports inputs like "9876543210", "+91 98765-43210", "09876543210", etc.
 */
export function normalizePhone(raw: string): string {
  if (!raw) {
    throw new Error("Phone number is required");
  }

  // Strip all non-digit and non-plus characters
  let clean = raw.trim().replace(/[\s\-\(\)\.]/g, "");

  if (clean.startsWith("+")) {
    const digitsOnly = clean.substring(1);
    if (!/^\d{10,15}$/.test(digitsOnly)) {
      throw new Error(`Invalid international phone format: ${raw}`);
    }
    return clean;
  }

  // Remove leading 0 if present (common local dialing prefix in India)
  if (clean.startsWith("0")) {
    clean = clean.substring(1);
  }

  // If already starts with 91 followed by 10 digits
  if (clean.startsWith("91") && clean.length === 12) {
    return `+${clean}`;
  }

  // 10 digits standard Indian mobile
  if (/^\d{10}$/.test(clean)) {
    return `+91${clean}`;
  }

  throw new Error(`Invalid phone number format: ${raw}`);
}

/**
 * Masks a phone number for audit logs and safe UI display.
 * Format: +91******1234
 */
export function maskPhone(phone: string): string {
  try {
    const normalized = normalizePhone(phone);
    if (normalized.length <= 6) return "+91******";
    const last4 = normalized.slice(-4);
    const prefix = normalized.startsWith("+") ? normalized.slice(0, 3) : "+91";
    return `${prefix}******${last4}`;
  } catch {
    return "+91******0000";
  }
}
