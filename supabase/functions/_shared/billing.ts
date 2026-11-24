// Re-fetch-and-sync logic used by mp-webhook, mp-manage and mp-reconcile.
// Rule: the MP API (queried with OUR token) is the only source of truth; webhook
// bodies are never trusted. Rows with source = 'manual' are never modified.
import { getAdmin, mpEnv } from "./http.ts";
import { MpError, mp, mpId } from "./mp.ts";
import {
  computeSubscriptionState,
  type ExistingSub,
  authorizedPaymentToRecord,
  isMpId,
  mapAuthorizedPayment,
  mapPaymentStatus,
  parseExternalReference,
  payerEmailToBackfill,
} from "./logic.ts";

// deno-lint-ignore no-explicit-any
type Row = Record<string, any>;

export type SyncResult =
  | { result: "synced"; subscriptionId: string; status: string }
  | { result: "not_found" } // MP 404
  | { result: "unmatched" } // no row / unparseable external_reference
  | { result: "skipped_manual" }
  | { result: "env_mismatch" }
  | { result: "unknown_status" };

const graceDays = () => {
  const n = Number(Deno.env.get("MP_GRACE_DAYS") ?? 5);
  return Number.isFinite(n) && n >= 0 && n <= 30 ? n : 5;
};

async function findRow(preapprovalId: string, ref: string | null): Promise<Row | null> {
  const admin = getAdmin();
  const a = await admin.from("trainer_subscriptions").select("*").eq("mp_preapproval_id", preapprovalId).maybeSingle();
  if (a.error) throw new Error("db_select_failed");
  if (a.data) return a.data;
  if (ref) {
    const b = await admin.from("trainer_subscriptions").select("*").eq("external_reference", ref).maybeSingle();
    if (b.error) throw new Error("db_select_failed");
    return b.data ?? null;
  }
  return null;
}

/** Create the local row from a preapproval we created (insert may have been lost). */
async function adoptRow(preapprovalId: string, ref: string): Promise<Row | null> {
  const parsed = parseExternalReference(ref);
  if (!parsed) return null;
  const admin = getAdmin();
  const [{ data: plan }, { data: trainer }] = await Promise.all([
    admin.from("subscription_plans").select("id").eq("id", parsed.planId).maybeSingle(),
    admin.from("trainers").select("id").eq("user_id", parsed.payerUserId).maybeSingle(),
  ]);
  if (!plan || !trainer) return null;
  const now = new Date().toISOString();
  const { data, error } = await admin.from("trainer_subscriptions").insert({
    trainer_id: trainer.id,
    payer_user_id: parsed.payerUserId,
    payer_type: "trainer",
    plan_id: parsed.planId,
    starts_at: now,
    ends_at: now,
    is_active: false,
    source: "mp",
    status: "pending",
    mp_env: mpEnv(),
    mp_preapproval_id: preapprovalId,
    external_reference: ref,
  }).select("*").maybeSingle();
  if (error) {
    // Lost a race with another delivery: read the winner.
    return await findRow(preapprovalId, ref);
  }
  return data;
}

export async function syncPreapproval(
  preapprovalId: string,
  opts: { failedCharge?: boolean; approvedPaymentAt?: string | null } = {},
): Promise<SyncResult> {
  if (!isMpId(preapprovalId)) return { result: "not_found" };
  let pa: Row;
  try {
    pa = await mp<Row>("GET", `/preapproval/${mpId(preapprovalId)}`);
  } catch (e) {
    if (e instanceof MpError && (e.status === 404 || e.status === 400)) return { result: "not_found" };
    throw e;
  }

  const ref = typeof pa.external_reference === "string" ? pa.external_reference : null;
  let row = await findRow(preapprovalId, ref);
  if (!row && ref) row = await adoptRow(preapprovalId, ref);
  if (!row) return { result: "unmatched" };
  if (row.source === "manual") return { result: "skipped_manual" };
  if (row.mp_env && row.mp_env !== mpEnv()) return { result: "env_mismatch" };

  const existing: ExistingSub = {
    status: row.status,
    ends_at: row.ends_at ?? null,
    grace_until: row.grace_until ?? null,
    canceled_at: row.canceled_at ?? null,
    last_payment_at: row.last_payment_at ?? null,
  };

  // Payment evidence (first activation must never rest on mp status alone):
  // approved charge from the caller, the preapproval summary, a stored approved
  // mp_payments row, or - last resort - MP's own list of charges.
  const summarized = (pa.summarized ?? {}) as Row;
  const lastCharged = typeof summarized.last_charged_date === "string" ? summarized.last_charged_date : null;
  let evidencePaidAt: string | null = opts.approvedPaymentAt ?? lastCharged;
  let hasEvidence = !!evidencePaidAt || Number(summarized.charged_quantity) > 0;
  let chargesSynced = false;
  if (!hasEvidence && !row.last_payment_at && String(pa.status) !== "pending") {
    const { data: paid, error: paidErr } = await getAdmin().from("mp_payments")
      .select("paid_at").eq("mp_preapproval_id", preapprovalId).eq("status", "approved")
      .order("paid_at", { ascending: false, nullsFirst: false }).limit(1);
    if (paidErr) throw new Error("db_select_failed");
    if (paid?.length) {
      hasEvidence = true;
      evidencePaidAt = paid[0].paid_at ?? null;
    } else {
      try {
        const found = await syncChargesForPreapproval(preapprovalId, row.id);
        chargesSynced = true;
        if (found.approved) {
          hasEvidence = true;
          evidencePaidAt = found.paidAt;
        }
      } catch (e) {
        console.error("sync_charges_failed", e instanceof MpError ? `mp_${e.status}` : (e as Error).message || "error");
      }
    }
  }

  const state = computeSubscriptionState({
    mpStatus: String(pa.status ?? ""),
    nextPaymentDate: typeof pa.next_payment_date === "string" ? pa.next_payment_date : null,
    existing,
    failedCharge: !!opts.failedCharge,
    paymentEvidence: hasEvidence,
    now: new Date(),
    graceDays: graceDays(),
  });
  if (!state) return { result: "unknown_status" };

  const patch: Row = {
    ...state,
    mp_status: String(pa.status),
    mp_env: mpEnv(),
    mp_preapproval_id: preapprovalId,
    next_payment_date: typeof pa.next_payment_date === "string" ? pa.next_payment_date : null,
  };
  const paidAt = opts.approvedPaymentAt ?? evidencePaidAt;
  if (paidAt) patch.last_payment_at = paidAt;
  // Never blank out / overwrite payer_email (MP returns "" on fetch).
  const backfill = payerEmailToBackfill(row.payer_email, pa.payer_email);
  if (backfill) patch.payer_email = backfill;

  // Defense in depth: charged amount must match our plan price.
  if (state.status === "authorized") {
    const { data: plan } = await getAdmin().from("subscription_plans").select("price").eq("id", row.plan_id).maybeSingle();
    const amt = Number((pa.auto_recurring as Row | undefined)?.transaction_amount);
    if (plan && Number.isFinite(amt) && Number(plan.price) !== amt) {
      console.warn("amount_mismatch", { subscription: row.id });
    }
  }

  // .neq guards against an admin flipping the row to manual mid-flight.
  const { error } = await getAdmin().from("trainer_subscriptions")
    .update(patch).eq("id", row.id).neq("source", "manual");
  if (error) throw new Error("db_update_failed");
  // Charge history is best-effort: it must never fail or undo the sync above.
  if (!chargesSynced) {
    try {
      await syncChargesForPreapproval(preapprovalId, row.id);
    } catch (e) {
      console.error("sync_charges_failed", e instanceof MpError ? `mp_${e.status}` : (e as Error).message || "error");
    }
  }

  // First real activation (paid, previously not paid): retire the payer's other
  // live MP subscriptions so an upgrade never double-bills. Best effort; never
  // undoes the sync above.
  if (state.status === "authorized" && hasEvidence && !row.last_payment_at) {
    try {
      await cancelSupersededSubscriptions(row);
    } catch (e) {
      console.error("supersede_failed", e instanceof MpError ? `mp_${e.status}` : (e as Error).message || "error");
    }
  }
  return { result: "synced", subscriptionId: row.id, status: state.status };
}

const MAX_CHARGES = 50;
const MAX_SUPERSEDED = 5;

/**
 * Cancel the same payer's OTHER live source='mp' subscriptions (upgrade /
 * plan switch). Only rows created BEFORE `row` are retired, so two concurrent
 * first activations can never cancel each other. Cancelling on MP keeps access
 * until the paid-through date (syncPreapproval mirrors it as cancelled + ends_at),
 * exactly like mp-manage. Idempotent: once cancelled they no longer match.
 */
async function cancelSupersededSubscriptions(row: Row): Promise<void> {
  if (!row.payer_user_id || !row.created_at) return;
  const { data: others, error } = await getAdmin().from("trainer_subscriptions")
    .select("id, mp_preapproval_id")
    .eq("payer_user_id", row.payer_user_id).eq("source", "mp").eq("mp_env", mpEnv())
    .neq("id", row.id).not("mp_preapproval_id", "is", null)
    .in("status", ["authorized", "pending", "paused", "past_due"])
    .lt("created_at", row.created_at)
    .order("created_at", { ascending: true }).limit(MAX_SUPERSEDED);
  if (error) throw new Error("db_select_failed");
  for (const o of others ?? []) {
    const oid = String(o.mp_preapproval_id);
    if (oid === row.mp_preapproval_id || !isMpId(oid)) continue;
    try {
      await mp("PUT", `/preapproval/${mpId(oid)}`, { status: "cancelled" });
    } catch (e) {
      // 404/400 = already gone or not cancellable: still re-sync to mirror MP.
      console.error("supersede_cancel_failed", e instanceof MpError ? `mp_${e.status}` : "error");
    }
    try {
      await syncPreapproval(oid);
    } catch (e) {
      console.error("supersede_sync_failed", e instanceof MpError ? `mp_${e.status}` : (e as Error).message || "error");
    }
  }
}

/** Upsert the charges MP lists for OUR preapproval into mp_payments (idempotent).
 *  Returns whether an approved charge was seen (and its date). */
async function syncChargesForPreapproval(
  preapprovalId: string,
  subscriptionId: string,
): Promise<{ approved: boolean; paidAt: string | null }> {
  const found = { approved: false, paidAt: null as string | null };
  if (!isMpId(preapprovalId)) return found;
  const res = await mp<Row>(
    "GET",
    `/authorized_payments/search?preapproval_id=${mpId(preapprovalId)}`,
  );
  const results = Array.isArray(res?.results) ? (res.results as Row[]).slice(0, MAX_CHARGES) : [];
  let failed = 0;
  for (const ap of results) {
    // Defense in depth: only charges that belong to this preapproval.
    if (ap.preapproval_id != null && String(ap.preapproval_id) !== preapprovalId) continue;
    const rec = authorizedPaymentToRecord(ap as Parameters<typeof authorizedPaymentToRecord>[0]);
    if (!rec) continue;
    if (rec.outcome === "approved") {
      found.approved = true;
      if (rec.paidAt && (!found.paidAt || Date.parse(rec.paidAt) > Date.parse(found.paidAt))) found.paidAt = rec.paidAt;
    }
    try {
      await recordPayment({ id: subscriptionId }, {
        mpPaymentId: rec.mpPaymentId,
        preapprovalId,
        status: rec.status,
        statusDetail: rec.statusDetail,
        amount: rec.amount,
        currency: rec.currency,
        paidAt: rec.paidAt,
        raw: ap,
      });
    } catch {
      failed++;
    }
  }
  if (failed) console.error("sync_charges_partial", { failed });
  return found;
}

// Trimmed copy of a payment object: ids, status and amounts only.
function trimRaw(o: Row): Row {
  const keys = ["id", "status", "status_detail", "transaction_amount", "currency_id", "preapproval_id",
    "retry_attempt", "debit_date", "date_created", "last_modified", "date_approved", "reason"];
  const out: Row = {};
  for (const k of keys) if (o[k] !== undefined) out[k] = o[k];
  return out;
}

async function recordPayment(sub: { id: string }, p: {
  mpPaymentId: string;
  preapprovalId: string;
  status: string;
  statusDetail: string | null;
  amount: number | null;
  currency: string | null;
  paidAt: string | null;
  raw: Row;
}): Promise<void> {
  const admin = getAdmin();
  const { data: row } = await admin.from("trainer_subscriptions")
    .select("id, source, trainer_id, payer_user_id").eq("id", sub.id).maybeSingle();
  if (!row || row.source === "manual") return;
  const { error } = await admin.from("mp_payments").upsert({
    subscription_id: row.id,
    payer_user_id: row.payer_user_id,
    trainer_id: row.trainer_id,
    mp_preapproval_id: p.preapprovalId,
    mp_payment_id: p.mpPaymentId,
    mp_env: mpEnv(),
    amount: p.amount,
    currency_id: p.currency ?? "ARS",
    status: p.status,
    status_detail: p.statusDetail,
    paid_at: p.paidAt,
    raw: trimRaw(p.raw),
  }, { onConflict: "mp_payment_id" });
  if (error) throw new Error("db_payment_upsert_failed");
}

/** Topic subscription_authorized_payment. */
export async function syncAuthorizedPayment(id: string): Promise<SyncResult> {
  if (!isMpId(id)) return { result: "not_found" };
  let ap: Row;
  try {
    ap = await mp<Row>("GET", `/authorized_payments/${mpId(id)}`);
  } catch (e) {
    if (e instanceof MpError && (e.status === 404 || e.status === 400)) return { result: "not_found" };
    throw e;
  }
  const preapprovalId = ap.preapproval_id != null ? String(ap.preapproval_id) : "";
  if (!isMpId(preapprovalId)) return { result: "unmatched" };

  const outcome = mapAuthorizedPayment(ap as Parameters<typeof mapAuthorizedPayment>[0]);
  const paidAt = outcome === "approved"
    ? String(ap.debit_date ?? ap.last_modified ?? new Date().toISOString())
    : null;
  const res = await syncPreapproval(preapprovalId, {
    failedCharge: outcome === "failed",
    approvedPaymentAt: paidAt,
  });
  if (res.result !== "synced") return res;

  const pay = (ap.payment ?? {}) as Row;
  const mpPaymentId = pay.id != null ? String(pay.id) : `ap-${id}`;
  const status = outcome === "approved"
    ? "approved"
    : outcome === "failed"
    ? (mapPaymentStatus(pay.status) === "unknown" ? "rejected" : mapPaymentStatus(pay.status))
    : outcome === "scheduled"
    ? "pending"
    : mapPaymentStatus(pay.status);
  if (outcome !== "scheduled") {
    const amt = Number(ap.transaction_amount);
    await recordPayment({ id: res.subscriptionId }, {
      mpPaymentId,
      preapprovalId,
      status,
      statusDetail: typeof pay.status_detail === "string" ? pay.status_detail : null,
      amount: Number.isFinite(amt) ? amt : null,
      currency: typeof ap.currency_id === "string" ? ap.currency_id : null,
      paidAt,
      raw: ap,
    });
  }
  return res;
}

/** Topic payment (secondary). Only acts when the payment is linkable to a preapproval. */
export async function syncPayment(id: string): Promise<SyncResult> {
  if (!isMpId(id)) return { result: "not_found" };
  let pay: Row;
  try {
    pay = await mp<Row>("GET", `/v1/payments/${mpId(id)}`);
  } catch (e) {
    if (e instanceof MpError && (e.status === 404 || e.status === 400)) return { result: "not_found" };
    throw e;
  }
  let preapprovalId = (pay.metadata as Row | undefined)?.preapproval_id;
  preapprovalId = preapprovalId != null ? String(preapprovalId) : "";
  if (!isMpId(preapprovalId)) {
    const ref = typeof pay.external_reference === "string" ? pay.external_reference : null;
    if (!ref) return { result: "unmatched" };
    const { data } = await getAdmin().from("trainer_subscriptions")
      .select("mp_preapproval_id").eq("external_reference", ref).maybeSingle();
    preapprovalId = data?.mp_preapproval_id ?? "";
    if (!isMpId(preapprovalId)) return { result: "unmatched" };
  }
  const status = mapPaymentStatus(pay.status as string);
  const paidAt = status === "approved" ? String(pay.date_approved ?? new Date().toISOString()) : null;
  const res = await syncPreapproval(preapprovalId, {
    failedCharge: status === "rejected",
    approvedPaymentAt: paidAt,
  });
  if (res.result !== "synced") return res;
  const amt = Number(pay.transaction_amount);
  await recordPayment({ id: res.subscriptionId }, {
    mpPaymentId: String(pay.id ?? id),
    preapprovalId,
    status,
    statusDetail: typeof pay.status_detail === "string" ? pay.status_detail : null,
    amount: Number.isFinite(amt) ? amt : null,
    currency: typeof pay.currency_id === "string" ? pay.currency_id : null,
    paidAt,
    raw: pay,
  });
  return res;
}
