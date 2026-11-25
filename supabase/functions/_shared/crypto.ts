// Token-at-rest encryption (AES-256-GCM) and signed OAuth `state`.
// Key: MP_TOKEN_ENC_KEY = base64 of 32 random bytes (Edge Function secret).
// Generate once with: openssl rand -base64 32
import { HttpError, requireEnv } from "./http.ts";
import { constantTimeEqual, hmacSha256Hex } from "./logic.ts";

const b64 = {
  enc: (u: Uint8Array) => btoa(String.fromCharCode(...u)),
  dec: (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0)),
};
const b64url = {
  enc: (s: string) => btoa(s).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", ""),
  dec: (s: string) => atob(s.replaceAll("-", "+").replaceAll("_", "/")),
};

async function aesKey(): Promise<CryptoKey> {
  const raw = b64.dec(requireEnv("MP_TOKEN_ENC_KEY"));
  if (raw.length !== 32) throw new HttpError(500, "Configuracion invalida: MP_TOKEN_ENC_KEY");
  return crypto.subtle.importKey("raw", raw, "AES-GCM", false, ["encrypt", "decrypt"]);
}

/** -> "<iv b64>.<ciphertext b64>" */
export async function encryptToken(plain: string): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(
    await crypto.subtle.encrypt({ name: "AES-GCM", iv }, await aesKey(), new TextEncoder().encode(plain)),
  );
  return `${b64.enc(iv)}.${b64.enc(ct)}`;
}

export async function decryptToken(stored: string): Promise<string> {
  const [iv, ct] = stored.split(".");
  if (!iv || !ct) throw new Error("bad_token_format");
  const pt = await crypto.subtle.decrypt({ name: "AES-GCM", iv: b64.dec(iv) }, await aesKey(), b64.dec(ct));
  return new TextDecoder().decode(pt);
}

/** Signed, expiring OAuth state binding the callback to one trainer. */
export async function signState(trainerId: string, ttlSeconds = 600): Promise<string> {
  const payload = b64url.enc(JSON.stringify({
    t: trainerId,
    exp: Math.floor(Date.now() / 1000) + ttlSeconds,
    n: crypto.randomUUID(),
  }));
  const sig = await hmacSha256Hex(requireEnv("MP_TOKEN_ENC_KEY"), payload);
  return `${payload}.${sig}`;
}

/** Returns the trainer id, or null if forged / expired / malformed. */
export async function verifyState(state: string | null): Promise<string | null> {
  if (!state || state.length > 600) return null;
  const [payload, sig] = state.split(".");
  if (!payload || !sig) return null;
  const expect = await hmacSha256Hex(requireEnv("MP_TOKEN_ENC_KEY"), payload);
  if (!constantTimeEqual(expect, sig)) return null;
  try {
    const p = JSON.parse(b64url.dec(payload));
    if (typeof p.t !== "string" || typeof p.exp !== "number") return null;
    if (p.exp < Date.now() / 1000) return null;
    return p.t;
  } catch {
    return null;
  }
}
