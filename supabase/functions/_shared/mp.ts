// Minimal Mercado Pago REST client. The base URL is a constant and every
// path segment is validated, so no caller-controlled value can redirect the
// request (SSRF) or traverse paths. The access token is read from env only
// and never logged.
import { HttpError, requireEnv } from "./http.ts";
import { isMpId } from "./logic.ts";

const MP_BASE = "https://api.mercadopago.com";

export class MpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
  /** 5xx / 429 / network => worth retrying. */
  get transient(): boolean {
    return this.status === 0 || this.status === 429 || this.status >= 500;
  }
}

export function mpId(id: unknown): string {
  if (!isMpId(id)) throw new HttpError(400, "Identificador invalido");
  return encodeURIComponent(id);
}

/** Call MP as the PRGS platform account (trainer -> PRGS billing). */
export function mp<T = Record<string, unknown>>(
  method: "GET" | "POST" | "PUT",
  path: string, // always built from literals + mpId()
  body?: unknown,
  idempotencyKey?: string,
): Promise<T> {
  return mpAs<T>(requireEnv("MP_ACCESS_TOKEN"), method, path, body, idempotencyKey);
}

/** Call MP with an explicit token (a trainer's connected account). */
export async function mpAs<T = Record<string, unknown>>(
  token: string,
  method: "GET" | "POST" | "PUT",
  path: string, // always built from literals + mpId()
  body?: unknown,
  idempotencyKey?: string,
): Promise<T> {
  const headers: Record<string, string> = {
    Authorization: `Bearer ${token}`,
    Accept: "application/json",
  };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (method === "POST") headers["X-Idempotency-Key"] = idempotencyKey ?? crypto.randomUUID();

  let res: Response;
  try {
    res = await fetch(`${MP_BASE}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(10_000),
    });
  } catch {
    throw new MpError(0, "mp_network_error");
  }

  const text = await res.text();
  let data: unknown = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch { /* non-JSON error page */ }

  if (!res.ok) {
    // Only the MP error code/message, never the request (may hold PII).
    const d = data as { message?: string; error?: string } | null;
    throw new MpError(res.status, String(d?.message ?? d?.error ?? `mp_http_${res.status}`).slice(0, 200));
  }
  return data as T;
}

/** init_point must be an https Mercado Pago URL before we hand it to a client. */
export function safeInitPoint(v: unknown): string | null {
  if (typeof v !== "string") return null;
  try {
    const u = new URL(v);
    if (u.protocol !== "https:") return null;
    if (!/(^|\.)mercadopago\.(com|com\.ar)$/.test(u.hostname) && !/(^|\.)mercadolibre\.com(\.ar)?$/.test(u.hostname)) {
      return null;
    }
    return u.toString();
  } catch {
    return null;
  }
}
