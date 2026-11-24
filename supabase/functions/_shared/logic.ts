// Pure billing logic (no I/O, no env, no npm imports) so it is unit-testable
// with `deno test`. Everything that touches MP / Postgres lives elsewhere.

// ---------------------------------------------------------------------------
// Validation helpers
// ---------------------------------------------------------------------------
export const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const isUuid = (v: unknown): v is string =>
  typeof v === "string" && UUID_RE.test(v);

// MP ids are numeric or short alphanumeric. Anything else must never reach a
// URL path (SSRF / path traversal guard).
export const MP_ID_RE = /^[A-Za-z0-9_-]{1,64}$/;
export const isMpId = (v: unknown): v is string =>
  typeof v === "string" && MP_ID_RE.test(v);

const EMAIL_RE = /^[^\s@<>()",;:]{1,64}@[^\s@<>()",;:]{1,255}\.[^\s@<>()",;:]{2,}$/;
export const isEmail = (v: unknown): v is string =>
  typeof v === "string" && v.length <= 254 && EMAIL_RE.test(v);

/**
 * payer_email is write-once from MP: MP returns payer_email "" on preapproval
 * fetch, so only a valid, non-empty email may be stored, and only when we have
 * none yet. Returns the value to write, or null = leave the column untouched.
 */
export function payerEmailToBackfill(existing: unknown, fromMp: unknown): string | null {
  if (typeof existing === "string" && existing.trim() !== "") return null;
  if (typeof fromMp !== "string") return null;
  const e = fromMp.trim().toLowerCase();
  return isEmail(e) ? e : null;
}

// ---------------------------------------------------------------------------
// external_reference: "<payer_user_id>:<plan_id>:<nonce>"
// The nonce lets a payer re-subscribe to the same plan after a cancellation
// (cancelled preapprovals cannot be reactivated and the column is unique).
// A legacy 2-part form "<payer>:<plan>" is also accepted when parsing.
// ---------------------------------------------------------------------------
export function buildExternalReference(
  payerUserId: string,
  planId: string,
  nonce: string,
): string {
  return `${payerUserId}:${planId}:${nonce}`;
}

export function parseExternalReference(
  ref: unknown,
): { payerUserId: string; planId: string } | null {
  if (typeof ref !== "string" || ref.length > 256) return null;
  const parts = ref.split(":");
  if (parts.length < 2 || parts.length > 3) return null;
  const [payerUserId, planId] = parts;
  if (!isUuid(payerUserId) || !isUuid(planId)) return null;
  return { payerUserId: payerUserId.toLowerCase(), planId: planId.toLowerCase() };
}

// ---------------------------------------------------------------------------
// Webhook signature (x-signature: ts=<unix>,v1=<hex HMAC-SHA256>)
// manifest = "id:<data.id lowercased>;request-id:<x-request-id>;ts:<ts>;"
// Absent parts are omitted together with their ";".
// ---------------------------------------------------------------------------
export interface ParsedSignature {
  ts: string;
  v1: string;
}

export function parseSignatureHeader(header: string | null): ParsedSignature | null {
  if (!header || header.length > 512) return null;
  let ts: string | undefined;
  let v1: string | undefined;
  for (const part of header.split(",")) {
    const i = part.indexOf("=");
    if (i < 0) continue;
    const k = part.slice(0, i).trim();
    const v = part.slice(i + 1).trim();
    if (k === "ts" && ts === undefined) ts = v;
    else if (k === "v1" && v1 === undefined) v1 = v.toLowerCase();
  }
  if (!ts || !v1) return null;
  if (!/^\d{1,16}$/.test(ts)) return null;
  if (!/^[0-9a-f]{64}$/.test(v1)) return null;
  return { ts, v1 };
}

export function buildManifest(
  dataId: string | null,
  requestId: string | null,
  ts: string,
): string {
  let m = "";
  if (dataId) m += `id:${dataId.toLowerCase()};`;
  if (requestId) m += `request-id:${requestId};`;
  m += `ts:${ts};`;
  return m;
}

const enc = new TextEncoder();

export async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(message)));
  return Array.from(sig, (b) => b.toString(16).padStart(2, "0")).join("");
}

export function constantTimeEqual(a: string, b: string): boolean {
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  const n = Math.max(x.length, y.length);
  for (let i = 0; i < n; i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

export type SignatureResult =
  | { ok: true; ts: string }
  | { ok: false; reason: "no_secret" | "malformed" | "no_data_id" | "stale" | "mismatch" };

export async function verifyWebhookSignature(p: {
  secret: string | undefined;
  signatureHeader: string | null;
  requestId: string | null;
  dataId: string | null;
  nowMs: number;
  toleranceSeconds?: number;
}): Promise<SignatureResult> {
  // Fail closed: never accept anything without a configured secret.
  if (!p.secret) return { ok: false, reason: "no_secret" };
  const parsed = parseSignatureHeader(p.signatureHeader);
  if (!parsed) return { ok: false, reason: "malformed" };
  // We only act on notifications whose resource id is covered by the HMAC.
  if (!p.dataId) return { ok: false, reason: "no_data_id" };

  const tolerance = p.toleranceSeconds ?? 300;
  let tsMs = Number(parsed.ts);
  if (tsMs < 1e12) tsMs *= 1000; // seconds -> ms (tolerate ms timestamps)
  if (!Number.isFinite(tsMs) || Math.abs(p.nowMs - tsMs) > tolerance * 1000) {
    return { ok: false, reason: "stale" };
  }

  const expected = await hmacSha256Hex(
    p.secret,
    buildManifest(p.dataId, p.requestId, parsed.ts),
  );
  return constantTimeEqual(expected, parsed.v1)
    ? { ok: true, ts: parsed.ts }
    : { ok: false, reason: "mismatch" };
}

// ---------------------------------------------------------------------------
// Idempotency key for mp_webhook_events.event_key
// Per delivery (x-request-id) so that later legitimate updates of the same
// resource are NOT swallowed; a retry of the same delivery is a no-op.
// ---------------------------------------------------------------------------
export function deriveEventKey(p: {
  env: string;
  topic: string;
  resourceId: string;
  requestId: string | null;
  ts: string;
}): string {
  // Only values covered by the signature (data.id, x-request-id, ts) or derived
  // from our own config/resolution. The unsigned body `action` is NOT part of
  // the key: an attacker replaying a signed delivery could otherwise vary it
  // to dodge dedupe. (Rows written before this change used a 5-part key that
  // included `action`; they stay valid, only new events use the new shape.)
  const delivery = p.requestId ? `r:${p.requestId}` : `t:${p.ts}`;
  return [p.env, p.topic, p.resourceId.toLowerCase(), delivery].join("|");
}

// ---------------------------------------------------------------------------
// Webhook topic resolution.
// The signature covers only data.id/request-id/ts, so the body and the query
// `type` are both untrusted hints: they may only choose WHICH MP endpoint the
// (regex-validated) id is re-fetched from. MP's panel simulator sends a query
// `type` that disagrees with the body `type`; the body is the accurate one.
// ---------------------------------------------------------------------------
export type WebhookTopic = "subscription_preapproval" | "subscription_authorized_payment" | "payment";

const KNOWN_TOPICS: readonly string[] = [
  "subscription_preapproval",
  "subscription_authorized_payment",
  "payment",
];
const ENTITY_TOPIC: Record<string, WebhookTopic> = {
  preapproval: "subscription_preapproval",
  authorized_payment: "subscription_authorized_payment",
  payment: "payment",
};

const knownTopic = (v: unknown): WebhookTopic | null =>
  typeof v === "string" && KNOWN_TOPICS.includes(v.trim().toLowerCase())
    ? (v.trim().toLowerCase() as WebhookTopic)
    : null;

/** Body `type` > body `entity` (mapped) > query type/topic. Returns the raw
 *  query value when nothing known is found (so it is still logged/ignored). */
export function resolveTopic(p: {
  bodyType?: unknown;
  bodyEntity?: unknown;
  queryType?: string | null;
  queryTopic?: string | null;
}): string {
  const fromBody = knownTopic(p.bodyType) ??
    (typeof p.bodyEntity === "string" ? ENTITY_TOPIC[p.bodyEntity.trim().toLowerCase()] ?? null : null);
  if (fromBody) return fromBody;
  const q = p.queryType ?? p.queryTopic ?? "";
  return knownTopic(q) ?? String(q).slice(0, 64);
}

/** Preapproval ids are 32 hex chars; authorized_payment/payment ids are numeric. */
export const looksLikePreapprovalId = (id: string): boolean => /^[0-9a-f]{32}$/i.test(id);

/** Ordered topics to try for a not_found-prone id. Max 2 attempts. */
export function topicAttempts(topic: string, resourceId: string): string[] {
  if ((topic === "subscription_authorized_payment" || topic === "payment") && looksLikePreapprovalId(resourceId)) {
    return [topic, "subscription_preapproval"];
  }
  return [topic];
}

// ---------------------------------------------------------------------------
// Status mapping
// ---------------------------------------------------------------------------
export type SubStatus =
  | "pending"
  | "authorized"
  | "paused"
  | "past_due"
  | "cancelled"
  | "expired";

export interface ExistingSub {
  status: SubStatus;
  ends_at: string | null;
  grace_until: string | null;
  canceled_at: string | null;
  /** Last confirmed charge. Absent/null = no payment ever recorded locally. */
  last_payment_at?: string | null;
}

export interface SubState {
  status: SubStatus;
  is_active: boolean;
  ends_at: string;
  grace_until: string | null;
  cancel_at_period_end: boolean;
  canceled_at: string | null;
}

const DAY_MS = 86_400_000;
const addDays = (d: Date, n: number) => new Date(d.getTime() + n * DAY_MS);
const parseDate = (v: string | null | undefined): Date | null => {
  if (!v) return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
};
const iso = (d: Date) => d.toISOString();

/**
 * Map the re-fetched MP preapproval to our normalized state. Returns null for
 * an unknown MP status (caller leaves the row untouched).
 *
 *  pending    -> pending, no access
 *  authorized -> authorized, ends_at = next_payment_date, grace_until = NULL
 *               (healthy rows get NO grace: access ends exactly at ends_at; the next
 *               successful charge moves ends_at forward, a failed one opens past_due)
 *  authorized + failed charge (and previously paid) -> past_due, grace window
 *  paused     -> paused, access until paid-through date
 *  cancelled  -> cancelled, access until paid-through date, then expired
 */
export function computeSubscriptionState(i: {
  mpStatus: string;
  nextPaymentDate: string | null;
  existing: ExistingSub | null;
  failedCharge: boolean;
  /** True when an approved charge exists for this preapproval (approved
   *  authorized_payment / mp_payments row / summarized.charged_quantity > 0 /
   *  last_charged_date). Required for first activation. */
  paymentEvidence?: boolean;
  now: Date;
  graceDays?: number;
  fallbackPeriodDays?: number;
}): SubState | null {
  const grace = i.graceDays ?? 5;
  const now = i.now;
  const ex = i.existing;
  const exEnds = parseDate(ex?.ends_at);
  const exGrace = parseDate(ex?.grace_until);
  // "Never paid" = no confirmed charge anywhere, NOT merely status pending.
  const neverPaid = !i.paymentEvidence && !ex?.last_payment_at;

  switch (i.mpStatus) {
    case "pending":
      return {
        status: "pending",
        is_active: false,
        ends_at: iso(exEnds ?? now),
        grace_until: null,
        cancel_at_period_end: false,
        canceled_at: null,
      };

    case "authorized": {
      const next = parseDate(i.nextPaymentDate);
      // First activation needs payment evidence: authorized without a charge
      // (card still being tokenised, first charge failed or not yet run) stays
      // pending/inactive and never starts the failed-charge grace. The webhook
      // or reconcile promotes it once the charge lands.
      if (neverPaid) {
        return {
          status: "pending",
          is_active: false,
          ends_at: iso(exEnds ?? now),
          grace_until: null,
          cancel_at_period_end: false,
          canceled_at: null,
        };
      }
      if (i.failedCharge) {
        const keep = ex?.status === "past_due" && exGrace;
        return {
          status: "past_due",
          is_active: true,
          ends_at: iso(exEnds ?? now),
          grace_until: iso(keep ? exGrace : addDays(now, grace)),
          cancel_at_period_end: false,
          canceled_at: null,
        };
      }
      // Drift-fix runs (no payment info) must not clear an open past_due until
      // MP shows the charge period advanced.
      if (ex?.status === "past_due" && exEnds && (!next || next.getTime() <= exEnds.getTime())) {
        return {
          status: "past_due",
          is_active: true,
          ends_at: iso(exEnds),
          grace_until: iso(exGrace ?? addDays(now, grace)),
          cancel_at_period_end: false,
          canceled_at: null,
        };
      }
      const ends = next ?? exEnds ?? addDays(now, i.fallbackPeriodDays ?? 30);
      return {
        status: "authorized",
        is_active: true,
        ends_at: iso(ends),
        grace_until: null,
        cancel_at_period_end: false,
        canceled_at: null,
      };
    }

    case "paused": {
      const ends = exEnds ?? now;
      return {
        status: "paused",
        is_active: !neverPaid && ends.getTime() > now.getTime(),
        ends_at: iso(ends),
        grace_until: null,
        cancel_at_period_end: false,
        canceled_at: null,
      };
    }

    case "cancelled": {
      const canceledAt = ex?.canceled_at ?? iso(now);
      if (neverPaid) {
        return {
          status: "cancelled",
          is_active: false,
          ends_at: iso(exEnds ?? now),
          grace_until: null,
          cancel_at_period_end: false,
          canceled_at: canceledAt,
        };
      }
      const untilMs = Math.max(exEnds?.getTime() ?? 0, exGrace?.getTime() ?? 0);
      if (untilMs > now.getTime()) {
        return {
          status: "cancelled",
          is_active: true,
          ends_at: iso(exEnds ?? now),
          grace_until: exGrace ? iso(exGrace) : null,
          cancel_at_period_end: true,
          canceled_at: canceledAt,
        };
      }
      return {
        status: "expired",
        is_active: false,
        ends_at: iso(exEnds ?? now),
        grace_until: null,
        cancel_at_period_end: true,
        canceled_at: canceledAt,
      };
    }

    default:
      return null;
  }
}

/** True when a cancelled/paused/past_due row has run past its access window. */
export function isAccessExpired(
  row: { status: string; ends_at: string | null; grace_until: string | null },
  now: Date,
): boolean {
  if (!["cancelled", "paused", "past_due"].includes(row.status)) return false;
  const until = Math.max(
    parseDate(row.ends_at)?.getTime() ?? 0,
    parseDate(row.grace_until)?.getTime() ?? 0,
  );
  return until <= now.getTime();
}

/**
 * A "healthy" authorized MP row whose paid-through date already passed: the
 * renewal charge/webhook never landed (or was dropped), so it needs a re-sync.
 */
export function isRenewalOverdue(
  row: { status: string; ends_at: string | null },
  now: Date,
): boolean {
  if (row.status !== "authorized") return false;
  const end = parseDate(row.ends_at);
  return end !== null && end.getTime() <= now.getTime();
}

export type ChargeOutcome = "approved" | "failed" | "scheduled" | "unknown";

/** authorized_payment (subscription_authorized_payment topic) -> outcome. */
export function mapAuthorizedPayment(ap: {
  status?: string;
  payment?: { status?: string } | null;
}): ChargeOutcome {
  const s = ap.status;
  const p = ap.payment?.status;
  if (s === "processed" && p === "approved") return "approved";
  if (s === "recycling" || s === "cancelled") return "failed";
  if (p === "rejected" || p === "cancelled") return "failed";
  if (s === "scheduled") return "scheduled";
  return "unknown";
}

/** MP payment status -> our mp_payments.status. */
export function mapPaymentStatus(s: string | undefined | null): string {
  switch (s) {
    case "approved":
    case "authorized":
      return "approved";
    case "pending":
    case "in_process":
    case "in_mediation":
      return "pending";
    case "rejected":
      return "rejected";
    case "cancelled":
      return "cancelled";
    case "refunded":
    case "charged_back":
      return "refunded";
    default:
      return "unknown";
  }
}

export interface PaymentRecord {
  mpPaymentId: string;
  status: string;
  statusDetail: string | null;
  amount: number | null;
  currency: string | null;
  paidAt: string | null;
  outcome: ChargeOutcome;
}

/**
 * authorized_payment object -> mp_payments row values. Returns null for a
 * charge that has not happened yet (scheduled). The key is the MP payment id
 * when present, else "ap-<authorized_payment id>" (unique either way).
 */
export function authorizedPaymentToRecord(ap: {
  id?: unknown;
  status?: string;
  payment?: { id?: unknown; status?: string; status_detail?: unknown } | null;
  transaction_amount?: unknown;
  currency_id?: unknown;
  debit_date?: unknown;
  last_modified?: unknown;
}): PaymentRecord | null {
  const outcome = mapAuthorizedPayment(ap);
  if (outcome === "scheduled") return null;
  if (ap.id == null && ap.payment?.id == null) return null;
  const pay = ap.payment ?? {};
  const mpPaymentId = pay.id != null ? String(pay.id) : `ap-${String(ap.id)}`;
  if (!isMpId(mpPaymentId)) return null;
  const status = outcome === "approved"
    ? "approved"
    : outcome === "failed"
    ? (mapPaymentStatus(pay.status) === "unknown" ? "rejected" : mapPaymentStatus(pay.status))
    : mapPaymentStatus(pay.status);
  const amt = Number(ap.transaction_amount);
  const paidRaw = ap.debit_date ?? ap.last_modified;
  return {
    mpPaymentId,
    status,
    statusDetail: typeof pay.status_detail === "string" ? pay.status_detail : null,
    amount: ap.transaction_amount != null && Number.isFinite(amt) ? amt : null,
    currency: typeof ap.currency_id === "string" ? ap.currency_id : null,
    paidAt: outcome === "approved" && typeof paidRaw === "string" && parseDate(paidRaw) ? paidRaw : null,
    outcome,
  };
}
