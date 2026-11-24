// HTTP plumbing shared by the mp-* functions: CORS allow-list, JSON helpers,
// typed errors, bounded body reading, and the admin/user auth gates.
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

export class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

// ---- env (fail with a clear message, never a literal fallback) -------------
export function requireEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new HttpError(500, `Configuracion faltante: ${name}`);
  return v;
}

export function mpEnv(): "test" | "prod" {
  const v = Deno.env.get("MP_ENV");
  if (v !== "test" && v !== "prod") {
    throw new HttpError(500, "Configuracion invalida: MP_ENV debe ser test o prod");
  }
  return v;
}

let _admin: SupabaseClient | null = null;
/** Service-role client. Server-side only; bypasses RLS. */
export function getAdmin(): SupabaseClient {
  if (!_admin) {
    _admin = createClient(
      requireEnv("SUPABASE_URL"),
      requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
  }
  return _admin;
}

// ---- CORS ------------------------------------------------------------------
// Allow-list instead of "*": these endpoints carry user JWTs. Native Flutter
// does not need CORS; only the web build (prgs.app) does. In test env,
// localhost dev servers are also allowed.
function allowedOrigin(origin: string | null): string | null {
  if (!origin) return null;
  const list = (Deno.env.get("ALLOWED_ORIGINS") ?? "https://prgs.app")
    .split(",").map((s) => s.trim()).filter(Boolean);
  if (list.includes(origin)) return origin;
  if (Deno.env.get("MP_ENV") === "test" && /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin)) {
    return origin;
  }
  return null;
}

export function corsHeaders(req: Request): Record<string, string> {
  const h: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
  const o = allowedOrigin(req.headers.get("Origin"));
  if (o) h["Access-Control-Allow-Origin"] = o;
  return h;
}

export const json = (req: Request | null, body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...(req ? corsHeaders(req) : {}),
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });

/** Read a JSON object body with a hard size cap. */
export async function readJson(req: Request, maxBytes = 8192): Promise<Record<string, unknown>> {
  const len = Number(req.headers.get("content-length") ?? 0);
  if (len > maxBytes) throw new HttpError(413, "Solicitud demasiado grande");
  const text = await req.text();
  if (text.length > maxBytes) throw new HttpError(413, "Solicitud demasiado grande");
  try {
    const v = JSON.parse(text);
    if (v === null || typeof v !== "object" || Array.isArray(v)) throw new Error();
    return v as Record<string, unknown>;
  } catch {
    throw new HttpError(400, "JSON invalido");
  }
}

/**
 * Wrap a handler: OPTIONS, method check, uniform error responses. Unexpected
 * errors return a generic message (details only in logs, never tokens/PII).
 */
export function serveJson(
  handler: (req: Request) => Promise<Response>,
): void {
  Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(req) });
    }
    if (req.method !== "POST") return json(req, { error: "Metodo no permitido" }, 405);
    try {
      return await handler(req);
    } catch (e) {
      if (e instanceof HttpError) return json(req, { error: e.message }, e.status);
      console.error("unhandled", e instanceof Error ? e.name : typeof e, e instanceof Error ? e.message : "");
      return json(req, { error: "Error interno" }, 500);
    }
  });
}

// ---- auth gates ------------------------------------------------------------
export interface Caller {
  userId: string;
  role: string | undefined;
}

export async function getCaller(req: Request): Promise<Caller> {
  const m = /^Bearer\s+(.+)$/i.exec(req.headers.get("Authorization") ?? "");
  if (!m) throw new HttpError(401, "No autorizado");
  const admin = getAdmin();
  const { data: { user }, error } = await admin.auth.getUser(m[1]);
  if (error || !user) throw new HttpError(401, "No autorizado");
  const { data: profile } = await admin.from("profiles").select("role").eq("id", user.id).maybeSingle();
  return { userId: user.id, role: profile?.role as string | undefined };
}

export async function requireAdmin(req: Request): Promise<Caller> {
  const c = await getCaller(req);
  if (c.role !== "admin") throw new HttpError(403, "No autorizado");
  return c;
}
