// Mercado Pago OAuth for connecting a trainer's own account, plus the
// "give me a valid token for this trainer" helper (refreshes near expiry).
// Secrets (MP_CLIENT_ID / MP_CLIENT_SECRET) come from env only, never logged.
import { decryptToken, encryptToken } from "./crypto.ts";
import { getAdmin, mpEnv, requireEnv } from "./http.ts";

const TOKEN_URL = "https://api.mercadopago.com/oauth/token";
const REFRESH_MARGIN_MS = 7 * 24 * 3_600_000; // refresh when < 7 days left

interface TokenResponse {
  access_token: string;
  refresh_token: string;
  user_id: number | string;
  expires_in: number;
}

async function tokenRequest(params: Record<string, string>): Promise<TokenResponse> {
  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify({
      client_id: requireEnv("MP_CLIENT_ID"),
      client_secret: requireEnv("MP_CLIENT_SECRET"),
      ...params,
    }),
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) throw new Error(`oauth_http_${res.status}`);
  const t = await res.json();
  if (!t?.access_token || !t?.refresh_token || t?.user_id == null) throw new Error("oauth_bad_response");
  return t as TokenResponse;
}

export const authorizationUrl = (state: string): string => {
  const u = new URL("https://auth.mercadopago.com.ar/authorization");
  u.searchParams.set("client_id", requireEnv("MP_CLIENT_ID"));
  u.searchParams.set("response_type", "code");
  u.searchParams.set("platform_id", "mp");
  u.searchParams.set("state", state);
  u.searchParams.set("redirect_uri", requireEnv("MP_OAUTH_REDIRECT_URI"));
  return u.toString();
};

/** Exchange the callback `code` and store the (encrypted) tokens for a trainer. */
export async function connectTrainer(trainerId: string, code: string): Promise<void> {
  const t = await tokenRequest({
    grant_type: "authorization_code",
    code,
    redirect_uri: requireEnv("MP_OAUTH_REDIRECT_URI"),
  });
  const { error } = await getAdmin().from("trainer_mp_accounts").upsert({
    trainer_id: trainerId,
    mp_user_id: String(t.user_id),
    mp_env: mpEnv(),
    access_token: await encryptToken(t.access_token),
    refresh_token: await encryptToken(t.refresh_token),
    expires_at: new Date(Date.now() + t.expires_in * 1000).toISOString(),
    updated_at: new Date().toISOString(),
  }, { onConflict: "trainer_id" });
  if (error) throw new Error(`store_failed_${error.code}`);
}

export interface TrainerMpAccount {
  trainerId: string;
  token: string;
}

/** Decrypted, fresh access token for a trainer (refreshes + persists if near expiry). */
export async function getTrainerAccount(trainerId: string): Promise<TrainerMpAccount | null> {
  const admin = getAdmin();
  const { data: row } = await admin.from("trainer_mp_accounts")
    .select("access_token, refresh_token, expires_at, mp_env").eq("trainer_id", trainerId).maybeSingle();
  if (!row || row.mp_env !== mpEnv()) return null;

  if (new Date(row.expires_at).getTime() - Date.now() > REFRESH_MARGIN_MS) {
    return { trainerId, token: await decryptToken(row.access_token) };
  }
  const t = await tokenRequest({
    grant_type: "refresh_token",
    refresh_token: await decryptToken(row.refresh_token),
  });
  await admin.from("trainer_mp_accounts").update({
    access_token: await encryptToken(t.access_token),
    refresh_token: await encryptToken(t.refresh_token),
    expires_at: new Date(Date.now() + t.expires_in * 1000).toISOString(),
    updated_at: new Date().toISOString(),
  }).eq("trainer_id", trainerId);
  return { trainerId, token: t.access_token };
}

export async function accountByMpUserId(mpUserId: string): Promise<string | null> {
  const { data } = await getAdmin().from("trainer_mp_accounts")
    .select("trainer_id").eq("mp_user_id", mpUserId).eq("mp_env", mpEnv()).maybeSingle();
  return (data?.trainer_id as string | undefined) ?? null;
}
