// Privacy-compliant logging: masks PII from stdout/stderr
import { maskPhone } from "./phone.ts";

export function safeLog(message: string, meta?: Record<string, unknown>) {
  const safeMeta = meta ? sanitizeMeta(meta) : undefined;
  if (safeMeta) {
    console.log(`[CareTrack] ${message}`, JSON.stringify(safeMeta));
  } else {
    console.log(`[CareTrack] ${message}`);
  }
}

export function safeError(message: string, error?: unknown) {
  const errMessage = error instanceof Error ? error.message : String(error ?? "");
  console.error(`[CareTrack Error] ${message}: ${errMessage}`);
}

function sanitizeMeta(meta: Record<string, unknown>): Record<string, unknown> {
  const sanitized: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(meta)) {
    const lk = key.toLowerCase();
    if (lk.includes("phone") || lk.includes("mobile")) {
      sanitized[key] = typeof value === "string" ? maskPhone(value) : "[MASKED]";
    } else if (lk.includes("name") || lk.includes("patient") || lk.includes("email") || lk.includes("medical") || lk.includes("notes")) {
      sanitized[key] = "[REDACTED_PII]";
    } else if (typeof value === "object" && value !== null && !Array.isArray(value)) {
      sanitized[key] = sanitizeMeta(value as Record<string, unknown>);
    } else {
      sanitized[key] = value;
    }
  }
  return sanitized;
}
