// Supabase Client Builders and Auth Verification Helpers
import { createClient, SupabaseClient, User } from "@supabase/supabase-js";

export function getSupabaseUrl(): string {
  const url = Deno.env.get("SUPABASE_URL");
  if (!url) throw new Error("SUPABASE_URL environment variable is missing");
  return url;
}

export function getAnonKey(): string {
  const key = Deno.env.get("SUPABASE_ANON_KEY");
  if (!key) throw new Error("SUPABASE_ANON_KEY environment variable is missing");
  return key;
}

export function getServiceRoleKey(): string {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!key) throw new Error("SUPABASE_SERVICE_ROLE_KEY environment variable is missing");
  return key;
}

/**
 * Creates an admin Supabase client using the service role key.
 * Used exclusively for background tasks, cron jobs, and admin operations.
 */
export function createServiceClient(): SupabaseClient {
  return createClient(getSupabaseUrl(), getServiceRoleKey(), {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

/**
 * Creates a scoped Supabase client with the caller's JWT from Authorization header.
 * Enforces PostgreSQL Row Level Security as that user.
 */
export function createAuthClient(req: Request): SupabaseClient {
  const authHeader = req.headers.get("Authorization");
  return createClient(getSupabaseUrl(), getAnonKey(), {
    global: {
      headers: authHeader ? { Authorization: authHeader } : {},
    },
    auth: {
      persistSession: false,
    },
  });
}

export interface UserProfile {
  id: string;
  clinic_id: string;
  role: "owner" | "doctor" | "receptionist";
  full_name: string;
  active: boolean;
}

export interface AuthenticatedContext {
  user: User;
  profile: UserProfile;
  supabase: SupabaseClient;
}

/**
 * Validates the JWT and fetches the user's active profile.
 * Throws an error if the user is unauthenticated or marked inactive.
 */
export async function getAuthenticatedUser(req: Request): Promise<AuthenticatedContext> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    throw new Error("Missing Authorization header");
  }

  const supabase = createAuthClient(req);
  const { data: { user }, error: authError } = await supabase.auth.getUser();

  if (authError || !user) {
    throw new Error("Invalid or expired session token");
  }

  // Fetch profile via service client to guarantee read of profile status
  const service = createServiceClient();
  const { data: profile, error: profileError } = await service
    .from("profiles")
    .select("id, clinic_id, role, full_name, active")
    .eq("id", user.id)
    .single();

  if (profileError || !profile) {
    throw new Error("User profile not found");
  }

  if (!profile.active) {
    throw new Error("Account has been deactivated. Please contact your clinic owner.");
  }

  return { user, profile: profile as UserProfile, supabase };
}

/**
 * Constant-time string comparison preventing timing attacks.
 */
export function constantTimeEquals(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}
