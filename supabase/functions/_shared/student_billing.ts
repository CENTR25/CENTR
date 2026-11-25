// Student billing on a TRAINER's connected Mercado Pago account.
// Everything here re-fetches the resource from MP with the trainer's token
// (webhook bodies are never trusted) and only touches rows that belong to that
// trainer. A confirmed charge: records a student_payments row (idempotent by MP
// payment id), moves athletes.next_renewal_date to MP's next_payment_date and
// lifts any access block.
import { getAdmin } from "./http.ts";
import { isMpId, isUuid, mapAuthorizedPayment } from "./logic.ts";
import { MpError, mpAs, mpId } from "./mp.ts";

// deno-lint-ignore no-explicit-any
type Row = Record<string, any>;
export type StudentSync =
  | { result: "synced"; subscriptionId: string; athleteId: string; nextPaymentDate: string | null }
  | { result: "not_found" | "unmatched" | "ignored" };

const LIVE = ["pending", "authorized", "paused", "cancelled"];
const REF_RE = /^student:([0-9a-f-]{36}):[A-Za-z0-9]{4,16}$/i;

export const buildStudentReference = (athleteId: string, nonce: string) => `student:${athleteId}:${nonce}`;

export async function syncStudentPreapproval(
  trainerId: string,
  token: string,
  preapprovalId: string,
): Promise<StudentSync> {
  if (!isMpId(preapprovalId)) return { result: "not_found" };
  let pa: Row;
  try {
    pa = await mpAs<Row>(token, "GET", `/preapproval/${mpId(preapprovalId)}`);
  } catch (e) {
    if (e instanceof MpError && (e.status === 404 || e.status === 400)) return { result: "not_found" };
    throw e;
  }
  const ref = typeof pa.external_reference === "string" ? pa.external_reference : "";
  const m = REF_RE.exec(ref);
  if (!m || !isUuid(m[1])) return { result: "unmatched" };

  const admin = getAdmin();
  // Scope by trainer_id: a reference can never touch another trainer's student.
  const { data: row } = await admin.from("student_subscriptions")
    .select("id, athlete_id").eq("external_reference", ref).eq("trainer_id", trainerId).maybeSingle();
  if (!row) return { result: "unmatched" };

  const status = LIVE.includes(pa.status) ? pa.status : "pending";
  const next = typeof pa.next_payment_date === "string" ? pa.next_payment_date : null;
  await admin.from("student_subscriptions").update({
    mp_preapproval_id: preapprovalId,
    status,
    next_payment_date: next,
    updated_at: new Date().toISOString(),
  }).eq("id", row.id);
  return { result: "synced", subscriptionId: row.id, athleteId: row.athlete_id, nextPaymentDate: next };
}

export async function syncStudentAuthorizedPayment(
  trainerId: string,
  token: string,
  id: string,
): Promise<StudentSync> {
  if (!isMpId(id)) return { result: "not_found" };
  let ap: Row;
  try {
    ap = await mpAs<Row>(token, "GET", `/authorized_payments/${mpId(id)}`);
  } catch (e) {
    if (e instanceof MpError && (e.status === 404 || e.status === 400)) return { result: "not_found" };
    throw e;
  }
  const preapprovalId = ap.preapproval_id != null ? String(ap.preapproval_id) : "";
  const res = await syncStudentPreapproval(trainerId, token, preapprovalId);
  if (res.result !== "synced") return res;

  if (mapAuthorizedPayment(ap as Parameters<typeof mapAuthorizedPayment>[0]) !== "approved") return res;

  const admin = getAdmin();
  const pay = (ap.payment ?? {}) as Row;
  const mpPaymentId = pay.id != null ? String(pay.id) : `ap-${id}`;
  if (!isMpId(mpPaymentId)) return res;
  const amount = Number(ap.transaction_amount);
  const paidIso = String(ap.debit_date ?? ap.last_modified ?? new Date().toISOString());
  const paidOn = (Number.isNaN(Date.parse(paidIso)) ? new Date() : new Date(paidIso)).toISOString().slice(0, 10);

  const ins = await admin.from("student_payments").insert({
    trainer_id: trainerId,
    athlete_id: res.athleteId,
    amount: Number.isFinite(amount) && amount > 0 ? amount : 0,
    paid_on: paidOn,
    note: "Mercado Pago (automático)",
    source: "mp",
    mp_payment_id: mpPaymentId,
  });
  if (ins.error) {
    if (ins.error.code === "23505") return res; // already recorded: no repeat side effects
    throw new Error(`record_payment_${ins.error.code}`);
  }

  await admin.from("student_subscriptions")
    .update({ last_payment_at: new Date().toISOString() }).eq("id", res.subscriptionId);

  // Paid: next due date = MP's next charge, and lift any block.
  const athleteUpdate: Row = { access_blocked: false, blocked_at: null, block_reason: null };
  if (res.nextPaymentDate && !Number.isNaN(Date.parse(res.nextPaymentDate))) {
    athleteUpdate.next_renewal_date = new Date(res.nextPaymentDate).toISOString().slice(0, 10);
  }
  await admin.from("athletes").update(athleteUpdate).eq("id", res.athleteId).eq("trainer_id", trainerId);
  return res;
}
