// Table-backed distributed rate limiter
import { createServiceClient } from "./clients.ts";
import { safeLog } from "./logger.ts";

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: Date;
}

export async function checkRateLimit(
  key: string,
  limit: number,
  windowSeconds: number
): Promise<RateLimitResult> {
  const service = createServiceClient();
  const now = new Date();
  const resetAt = new Date(now.getTime() + windowSeconds * 1000);

  try {
    // Fetch current bucket
    const { data, error } = await service
      .from("rate_limits")
      .select("key, count, reset_at")
      .eq("key", key)
      .maybeSingle();

    if (error) {
      safeLog("Rate limiter lookup error; defaulting to allow", { error: error.message });
      return { allowed: true, remaining: limit - 1, resetAt };
    }

    if (!data || new Date(data.reset_at) <= now) {
      // Initialize or reset window
      await service.from("rate_limits").upsert({
        key,
        count: 1,
        reset_at: resetAt.toISOString(),
      });
      return { allowed: true, remaining: limit - 1, resetAt };
    }

    // Window is still active
    if (data.count >= limit) {
      return {
        allowed: false,
        remaining: 0,
        resetAt: new Date(data.reset_at),
      };
    }

    // Increment count
    const nextCount = data.count + 1;
    await service
      .from("rate_limits")
      .update({ count: nextCount })
      .eq("key", key);

    return {
      allowed: true,
      remaining: Math.max(0, limit - nextCount),
      resetAt: new Date(data.reset_at),
    };
  } catch (err) {
    safeLog("Rate limiter exception; defaulting to allow", { error: String(err) });
    return { allowed: true, remaining: 1, resetAt };
  }
}
