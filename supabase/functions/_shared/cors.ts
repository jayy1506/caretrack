// CORS and HTTP response helpers
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-job-secret",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE",
};

export function handleCors(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  return null;
}

export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

export function errorResponse(message: string, status = 400, details?: unknown): Response {
  // Generic errors without stack traces for external safety
  return new Response(
    JSON.stringify({
      error: message,
      ...(details ? { details } : {}),
    }),
    {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    }
  );
}
