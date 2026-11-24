import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  buildExternalReference,
  buildManifest,
  computeSubscriptionState,
  constantTimeEqual,
  deriveEventKey,
  hmacSha256Hex,
  isAccessExpired,
  isRenewalOverdue,
  isEmail,
  payerEmailToBackfill,
  isMpId,
  looksLikePreapprovalId,
  resolveTopic,
  topicAttempts,
  authorizedPaymentToRecord,
  mapAuthorizedPayment,
  mapPaymentStatus,
  parseExternalReference,
  parseSignatureHeader,
  verifyWebhookSignature,
} from "./logic.ts";

const SECRET = "test-secret-not-real";
const NOW = Date.UTC(2026, 10, 23, 12, 0, 0);
const nowSec = String(Math.floor(NOW / 1000));
const DATA_ID = "ABC123";
const REQ = "req-1";

async function sign(ts: string, dataId: string | null = DATA_ID, req: string | null = REQ) {
  return `ts=${ts},v1=${await hmacSha256Hex(SECRET, buildManifest(dataId, req, ts))}`;
}

// ---- signature -------------------------------------------------------------
Deno.test("manifest lowercases data.id and omits absent parts", () => {
  assertEquals(buildManifest("ABC", "r", "1"), "id:abc;request-id:r;ts:1;");
  assertEquals(buildManifest(null, "r", "1"), "request-id:r;ts:1;");
  assertEquals(buildManifest("x", null, "1"), "id:x;ts:1;");
});

Deno.test("valid signature passes", async () => {
  const r = await verifyWebhookSignature({
    secret: SECRET,
    signatureHeader: await sign(nowSec),
    requestId: REQ,
    dataId: DATA_ID,
    nowMs: NOW,
  });
  assertEquals(r.ok, true);
});

Deno.test("forged signature (wrong secret) is rejected", async () => {
  const ts = nowSec;
  const forged = `ts=${ts},v1=${await hmacSha256Hex("other-secret", buildManifest(DATA_ID, REQ, ts))}`;
  const r = await verifyWebhookSignature({
    secret: SECRET, signatureHeader: forged, requestId: REQ, dataId: DATA_ID, nowMs: NOW,
  });
  assertEquals(r, { ok: false, reason: "mismatch" });
});

Deno.test("tampered data.id / request-id is rejected", async () => {
  const header = await sign(nowSec);
  for (const [dataId, req] of [["OTHER", REQ], [DATA_ID, "req-2"]] as const) {
    const r = await verifyWebhookSignature({
      secret: SECRET, signatureHeader: header, requestId: req, dataId, nowMs: NOW,
    });
    assertEquals(r, { ok: false, reason: "mismatch" });
  }
});

Deno.test("stale and far-future timestamps are rejected", async () => {
  for (const delta of [-10 * 60, 10 * 60]) {
    const ts = String(Math.floor(NOW / 1000) + delta);
    const r = await verifyWebhookSignature({
      secret: SECRET, signatureHeader: await sign(ts), requestId: REQ, dataId: DATA_ID, nowMs: NOW,
    });
    assertEquals(r, { ok: false, reason: "stale" });
  }
});

Deno.test("tolerance is configurable", async () => {
  const ts = String(Math.floor(NOW / 1000) - 3600);
  const r = await verifyWebhookSignature({
    secret: SECRET, signatureHeader: await sign(ts), requestId: REQ, dataId: DATA_ID,
    nowMs: NOW, toleranceSeconds: 7200,
  });
  assertEquals(r.ok, true);
});

Deno.test("malformed headers are rejected", async () => {
  const bad = [
    null, "", "garbage", "ts=abc,v1=" + "a".repeat(64), `ts=${nowSec}`,
    `v1=${"a".repeat(64)}`, `ts=${nowSec},v1=zzzz`, `ts=${nowSec},v1=${"a".repeat(63)}`,
    "x".repeat(1000),
  ];
  for (const h of bad) {
    const r = await verifyWebhookSignature({
      secret: SECRET, signatureHeader: h, requestId: REQ, dataId: DATA_ID, nowMs: NOW,
    });
    assertEquals(r, { ok: false, reason: "malformed" }, String(h));
  }
});

Deno.test("missing secret fails closed; missing data.id rejected", async () => {
  const header = await sign(nowSec);
  assertEquals(
    await verifyWebhookSignature({ secret: undefined, signatureHeader: header, requestId: REQ, dataId: DATA_ID, nowMs: NOW }),
    { ok: false, reason: "no_secret" },
  );
  assertEquals(
    await verifyWebhookSignature({ secret: "", signatureHeader: header, requestId: REQ, dataId: DATA_ID, nowMs: NOW }),
    { ok: false, reason: "no_secret" },
  );
  assertEquals(
    await verifyWebhookSignature({ secret: SECRET, signatureHeader: header, requestId: REQ, dataId: null, nowMs: NOW }),
    { ok: false, reason: "no_data_id" },
  );
});

Deno.test("uppercase hex v1 is accepted; constantTimeEqual behaves", async () => {
  const h = (await sign(nowSec)).replace(/v1=(.*)$/, (_, v) => `v1=${v.toUpperCase()}`);
  assertEquals((await verifyWebhookSignature({
    secret: SECRET, signatureHeader: h, requestId: REQ, dataId: DATA_ID, nowMs: NOW,
  })).ok, true);
  assert(constantTimeEqual("abc", "abc"));
  assert(!constantTimeEqual("abc", "abd"));
  assert(!constantTimeEqual("abc", "abcd"));
  assertEquals(parseSignatureHeader("ts=1, v1=" + "a".repeat(64))?.ts, "1");
});

// ---- event key -------------------------------------------------------------
Deno.test("event key is deterministic, per delivery, case-insensitive on id", () => {
  const base = { env: "test", topic: "subscription_preapproval", resourceId: "ABC", requestId: "r1", ts: "9" };
  assertEquals(deriveEventKey(base), deriveEventKey({ ...base, resourceId: "abc" }));
  assertEquals(deriveEventKey(base), "test|subscription_preapproval|abc|r:r1");
  assert(deriveEventKey(base) !== deriveEventKey({ ...base, requestId: "r2" }));
  assert(deriveEventKey(base) !== deriveEventKey({ ...base, env: "prod" }));
  assertEquals(deriveEventKey({ ...base, requestId: null }), "test|subscription_preapproval|abc|t:9");
  // unsigned body fields (action) can no longer influence the key
  assertEquals(deriveEventKey({ ...base, action: "created" } as never), deriveEventKey(base));
});

// ---- validators ------------------------------------------------------------
Deno.test("id / email / external_reference validators", () => {
  assert(isMpId("2c938084726fca480172750000000000"));
  assert(!isMpId("../../etc"));
  assert(!isMpId("a/b"));
  assert(!isMpId("a?b=1"));
  assert(!isMpId(""));
  assert(isEmail("a@b.com"));
  assert(!isEmail("a@b"));
  assert(!isEmail("a b@c.com"));
  assert(!isEmail('"x"@y.com'));
  const u = "11111111-1111-4111-8111-111111111111";
  const p = "22222222-2222-4222-8222-222222222222";
  assertEquals(parseExternalReference(buildExternalReference(u, p, "abcd1234")), { payerUserId: u, planId: p });
  assertEquals(parseExternalReference(`${u}:${p}`), { payerUserId: u, planId: p });
  assertEquals(parseExternalReference(`${u}:nope`), null);
  assertEquals(parseExternalReference("a:b:c:d"), null);
  assertEquals(parseExternalReference(null), null);
});

// ---- status mapping --------------------------------------------------------
const now = new Date(NOW);
const future = new Date(NOW + 10 * 86_400_000).toISOString();
const past = new Date(NOW - 10 * 86_400_000).toISOString();
const ex = (o: Partial<{ status: any; ends_at: string | null; grace_until: string | null; canceled_at: string | null; last_payment_at: string | null }>) =>
  ({ status: "authorized" as const, ends_at: future, grace_until: null, canceled_at: null, last_payment_at: past as string | null, ...o });
const pend = { status: "pending" as const, last_payment_at: null };

Deno.test("pending -> no access", () => {
  const s = computeSubscriptionState({ mpStatus: "pending", nextPaymentDate: null, existing: null, failedCharge: false, now })!;
  assertEquals([s.status, s.is_active], ["pending", false]);
});

Deno.test("authorized -> active, ends_at = next payment, NO grace when healthy", () => {
  const next = new Date(NOW + 30 * 86_400_000).toISOString();
  const s = computeSubscriptionState({ mpStatus: "authorized", nextPaymentDate: next, existing: ex(pend), failedCharge: false, paymentEvidence: true, now })!;
  assertEquals([s.status, s.is_active, s.ends_at], ["authorized", true, next]);
  assertEquals(s.grace_until, null);
  // A stale grace_until on a recovered/healthy row is cleared.
  const r = computeSubscriptionState({ mpStatus: "authorized", nextPaymentDate: next, existing: ex({ grace_until: new Date(NOW + 9e8).toISOString() }), failedCharge: false, now })!;
  assertEquals(r.grace_until, null);
});

Deno.test("authorizedPaymentToRecord maps charges, skips scheduled", () => {
  const ok = authorizedPaymentToRecord({ id: 7034254936, status: "processed", transaction_amount: 40000, currency_id: "ARS",
    debit_date: "2026-11-23T20:22:42.000-04:00", payment: { id: 191306938696, status: "approved", status_detail: "accredited" } })!;
  assertEquals([ok.mpPaymentId, ok.status, ok.amount, ok.currency, ok.statusDetail, ok.outcome], ["191306938696", "approved", 40000, "ARS", "accredited", "approved"]);
  assertEquals(ok.paidAt, "2026-11-23T20:22:42.000-04:00");
  const fail = authorizedPaymentToRecord({ id: 5, status: "recycling", transaction_amount: 10, payment: { status: "rejected" } })!;
  assertEquals([fail.mpPaymentId, fail.status, fail.paidAt], ["ap-5", "rejected", null]);
  assertEquals(authorizedPaymentToRecord({ id: 6, status: "scheduled" }), null);
  assertEquals(authorizedPaymentToRecord({}), null);
});

Deno.test("failed charge on a paid sub -> past_due with 5-day grace; repeat keeps grace", () => {
  const s = computeSubscriptionState({ mpStatus: "authorized", nextPaymentDate: null, existing: ex({ ends_at: past }), failedCharge: true, now })!;
  assertEquals([s.status, s.is_active, s.ends_at], ["past_due", true, past]);
  assertEquals(s.grace_until, new Date(NOW + 5 * 86_400_000).toISOString());
  const later = new Date(NOW + 2 * 86_400_000);
  const s2 = computeSubscriptionState({ mpStatus: "authorized", nextPaymentDate: null, existing: ex({ status: "past_due", ends_at: past, grace_until: s.grace_until }), failedCharge: true, now: later })!;
  assertEquals(s2.grace_until, s.grace_until);
});

Deno.test("failed FIRST charge never grants access", () => {
  const s = computeSubscriptionState({ mpStatus: "authorized", nextPaymentDate: null, existing: ex(pend), failedCharge: true, now })!;
  assertEquals([s.status, s.is_active], ["pending", false]);
  const s2 = computeSubscriptionState({ mpStatus: "authorized", nextPaymentDate: null, existing: null, failedCharge: true, now })!;
  assertEquals(s2.is_active, false);
});

Deno.test("drift fix does not clear past_due until period advances; recovery does", () => {
  const grace = new Date(NOW + 3 * 86_400_000).toISOString();
  const stuck = computeSubscriptionState({ mpStatus: "authorized", nextPaymentDate: past, existing: ex({ status: "past_due", ends_at: past, grace_until: grace }), failedCharge: false, now })!;
  assertEquals([stuck.status, stuck.grace_until], ["past_due", grace]);
  const next = new Date(NOW + 30 * 86_400_000).toISOString();
  const ok = computeSubscriptionState({ mpStatus: "authorized", nextPaymentDate: next, existing: ex({ status: "past_due", ends_at: past, grace_until: grace }), failedCharge: false, now })!;
  assertEquals([ok.status, ok.ends_at], ["authorized", next]);
});

Deno.test("cancelled keeps access until paid-through, then expires; never-paid is inactive", () => {
  const a = computeSubscriptionState({ mpStatus: "cancelled", nextPaymentDate: null, existing: ex({}), failedCharge: false, now })!;
  assertEquals([a.status, a.is_active, a.cancel_at_period_end, a.ends_at], ["cancelled", true, true, future]);
  const b = computeSubscriptionState({ mpStatus: "cancelled", nextPaymentDate: null, existing: ex({ ends_at: past }), failedCharge: false, now })!;
  assertEquals([b.status, b.is_active], ["expired", false]);
  const c = computeSubscriptionState({ mpStatus: "cancelled", nextPaymentDate: null, existing: ex(pend), failedCharge: false, now })!;
  assertEquals([c.status, c.is_active], ["cancelled", false]);
});

Deno.test("paused keeps paid-through; unknown status -> null", () => {
  const p = computeSubscriptionState({ mpStatus: "paused", nextPaymentDate: null, existing: ex({}), failedCharge: false, now })!;
  assertEquals([p.status, p.is_active, p.ends_at], ["paused", true, future]);
  assertEquals(computeSubscriptionState({ mpStatus: "weird", nextPaymentDate: null, existing: null, failedCharge: false, now }), null);
});

Deno.test("isAccessExpired", () => {
  assert(isAccessExpired({ status: "cancelled", ends_at: past, grace_until: null }, now));
  assert(!isAccessExpired({ status: "cancelled", ends_at: past, grace_until: future }, now));
  assert(!isAccessExpired({ status: "authorized", ends_at: past, grace_until: null }, now));
});

Deno.test("authorized_payment + payment status mapping", () => {
  assertEquals(mapAuthorizedPayment({ status: "processed", payment: { status: "approved" } }), "approved");
  assertEquals(mapAuthorizedPayment({ status: "recycling", payment: { status: "rejected" } }), "failed");
  assertEquals(mapAuthorizedPayment({ status: "cancelled" }), "failed");
  assertEquals(mapAuthorizedPayment({ status: "processed", payment: { status: "rejected" } }), "failed");
  assertEquals(mapAuthorizedPayment({ status: "scheduled" }), "scheduled");
  assertEquals(mapAuthorizedPayment({}), "unknown");
  assertEquals(mapPaymentStatus("in_process"), "pending");
  assertEquals(mapPaymentStatus("charged_back"), "refunded");
  assertEquals(mapPaymentStatus("zzz"), "unknown");
});

Deno.test("payerEmailToBackfill never blanks or overwrites payer_email", () => {
  assertEquals(payerEmailToBackfill("a@b.com", ""), null); // MP empty
  assertEquals(payerEmailToBackfill("a@b.com", "c@d.com"), null); // already set
  assertEquals(payerEmailToBackfill(null, ""), null);
  assertEquals(payerEmailToBackfill(null, undefined), null);
  assertEquals(payerEmailToBackfill("  ", "not-an-email"), null);
  assertEquals(payerEmailToBackfill(null, " C@D.com "), "c@d.com");
});

Deno.test("resolveTopic: body type wins over query, entity maps, unknown falls back", () => {
  // The real simulator case: query says authorized_payment, body says preapproval.
  assertEquals(
    resolveTopic({ bodyType: "subscription_preapproval", queryType: "subscription_authorized_payment" }),
    "subscription_preapproval",
  );
  assertEquals(resolveTopic({ bodyType: "payment", queryType: "subscription_preapproval" }), "payment");
  // entity fallback when body type missing/unknown
  assertEquals(resolveTopic({ bodyEntity: "preapproval", queryType: "payment" }), "subscription_preapproval");
  assertEquals(resolveTopic({ bodyType: "weird", bodyEntity: "authorized_payment" }), "subscription_authorized_payment");
  assertEquals(resolveTopic({ bodyEntity: "payment" }), "payment");
  // unknown body + unknown entity -> query
  assertEquals(resolveTopic({ bodyType: "zzz", bodyEntity: "qqq", queryType: "payment" }), "payment");
  assertEquals(resolveTopic({ queryTopic: "payment" }), "payment");
  assertEquals(resolveTopic({ queryType: "subscription_preapproval", queryTopic: "payment" }), "subscription_preapproval");
  // nothing usable -> raw query (ignored downstream), never body garbage
  assertEquals(resolveTopic({ bodyType: "x".repeat(200), queryType: "other" }), "other");
  assertEquals(resolveTopic({}), "");
  // non-string body values are ignored
  assertEquals(resolveTopic({ bodyType: { a: 1 }, bodyEntity: 5, queryType: "payment" }), "payment");
  // case/whitespace tolerant
  assertEquals(resolveTopic({ bodyType: " Subscription_Preapproval " }), "subscription_preapproval");
});

Deno.test("topicAttempts: preapproval-id fallback bounded to 2", () => {
  const pre = "7a6ff37b35eb4349b9abbe0f05829118";
  assert(looksLikePreapprovalId(pre));
  assert(!looksLikePreapprovalId("123456"));
  assertEquals(topicAttempts("subscription_authorized_payment", pre), ["subscription_authorized_payment", "subscription_preapproval"]);
  assertEquals(topicAttempts("payment", pre), ["payment", "subscription_preapproval"]);
  assertEquals(topicAttempts("payment", "123456"), ["payment"]);
  assertEquals(topicAttempts("subscription_preapproval", pre), ["subscription_preapproval"]);
  assertEquals(topicAttempts("other", pre), ["other"]);
});

Deno.test("isRenewalOverdue", () => {
  assert(isRenewalOverdue({ status: "authorized", ends_at: past }, now));
  assert(!isRenewalOverdue({ status: "authorized", ends_at: future }, now));
  assert(!isRenewalOverdue({ status: "authorized", ends_at: null }, now));
  assert(!isRenewalOverdue({ status: "cancelled", ends_at: past }, now));
});

Deno.test("first activation: authorized + approved charge -> active", () => {
  const next = new Date(NOW + 30 * 86_400_000).toISOString();
  const s = computeSubscriptionState({ mpStatus: "authorized", nextPaymentDate: next, existing: ex(pend), failedCharge: false, paymentEvidence: true, now })!;
  assertEquals([s.status, s.is_active, s.ends_at, s.grace_until], ["authorized", true, next, null]);
});

Deno.test("first activation: authorized with NO payment evidence -> pending, inactive", () => {
  const next = new Date(NOW + 30 * 86_400_000).toISOString();
  for (const existing of [ex(pend), null]) {
    const s = computeSubscriptionState({ mpStatus: "authorized", nextPaymentDate: next, existing, failedCharge: false, now })!;
    assertEquals([s.status, s.is_active, s.grace_until], ["pending", false, null]);
  }
  // an authorized row with a recorded payment (no fresh evidence) keeps working
  const r = computeSubscriptionState({ mpStatus: "authorized", nextPaymentDate: next, existing: ex({}), failedCharge: false, now })!;
  assertEquals([r.status, r.is_active], ["authorized", true]);
});

Deno.test("authorized then failed FIRST charge: inactive, no grace, status-independent", () => {
  // even if the row was already flipped to 'authorized' without payment
  const s = computeSubscriptionState({ mpStatus: "authorized", nextPaymentDate: null, existing: ex({ last_payment_at: null }), failedCharge: true, now })!;
  assertEquals([s.status, s.is_active, s.grace_until], ["pending", false, null]);
});
