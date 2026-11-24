// Authenticated trainer: start a subscription to a plan.
//   { plan_id: uuid, payer_email: string }  -> { init_point, subscription_id }
// Only plan_id (and the MP-account email) come from the client. Caller identity
// is the JWT; amount/currency/frequency are derived from subscription_plans.
// Access is NEVER granted here: the row is created 'pending' and only the
// verified webhook (or reconcile) can activate it.
import { getAdmin, getCaller, HttpError, json, mpEnv, readJson, requireEnv, serveJson } from "../_shared/http.ts";
import { buildExternalReference, isEmail, isUuid } from "../_shared/logic.ts";
import { MpError, mp, mpId, safeInitPoint } from "../_shared/mp.ts";

// deno-lint-ignore no-explicit-any
type Row = Record<string, any>;

const backUrl = () => Deno.env.get("BILLING_BACK_URL") ?? "https://prgs.app/billing/return";

// ---------------------------------------------------------------------------
// THE ONLY PLACE THAT KNOWS HOW A PAYER IS BOUND TO A PREAPPROVAL.
// Option A (current): standalone pending preapproval carrying external_reference
//   + payer_email; MP returns an init_point for the hosted checkout.
// Option A needs no MP plan (no mp_plan_id / sync_plans); price comes from subscription_plans.
// Option B (switch here only): card Brick -> card_token_id, then
//   POST /preapproval { preapproval_plan_id: plan.mp_plan_id, card_token_id,
//   external_reference, payer_email, status: "authorized" } and return
//   { preapprovalId, initPoint: null }. Add card_token to BindInput and the
//   request validation below; nothing else changes.
// ---------------------------------------------------------------------------
interface BindInput {
  plan: Row;
  externalReference: string;
  payerEmail: string;
  env: "test" | "prod";
}
interface BindResult {
  preapprovalId: string;
  initPoint: string | null;
}

async function bindPayerToPlan(b: BindInput, onCreated: (preapprovalId: string) => void): Promise<BindResult> {
  const prefix = b.env === "test" ? "[TEST] " : "";
  const created = await mp<Row>("POST", "/preapproval", {
    reason: `${prefix}PRGS ${b.plan.name}`.slice(0, 200),
    external_reference: b.externalReference,
    payer_email: b.payerEmail,
    back_url: backUrl(),
    status: "pending",
    auto_recurring: {
      frequency: Number(b.plan.frequency ?? 1),
      frequency_type: String(b.plan.frequency_type ?? "months"),
      transaction_amount: Number(b.plan.price),
      currency_id: String(b.plan.currency_id ?? "ARS"),
    },
  }, b.externalReference);
  if (!created.id) throw new HttpError(502, "Respuesta invalida de Mercado Pago");
  onCreated(String(created.id)); // from here on, any failure must cancel it on MP
  return { preapprovalId: String(created.id), initPoint: safeInitPoint(created.init_point) };
}

serveJson(async (req) => {
  const caller = await getCaller(req);
  if (caller.role !== "trainer") throw new HttpError(403, "Solo entrenadores pueden suscribirse");
  requireEnv("MP_ACCESS_TOKEN");
  const env = mpEnv();

  const body = await readJson(req);
  if (!isUuid(body.plan_id)) throw new HttpError(400, "plan_id invalido");
  if (!isEmail(body.payer_email)) {
    throw new HttpError(400, "Ingresa el email de tu cuenta de Mercado Pago");
  }
  const payerEmail = (body.payer_email as string).trim().toLowerCase();
  const admin = getAdmin();

  const { data: trainer } = await admin.from("trainers").select("id").eq("user_id", caller.userId).maybeSingle();
  if (!trainer) throw new HttpError(403, "Entrenador no encontrado");

  const { data: plan } = await admin.from("subscription_plans").select("*").eq("id", body.plan_id).maybeSingle();
  if (!plan || plan.audience !== "trainer" || !plan.is_active || (plan.mp_env != null && plan.mp_env !== env)) {
    throw new HttpError(404, "Plan no disponible");
  }
  if (plan.price_is_placeholder || !(Number(plan.price) > 0)) throw new HttpError(409, "Plan no disponible");

  // Never subscribe into a plan smaller than the current roster.
  if (plan.max_students != null) {
    const { count } = await admin.from("athletes").select("id", { count: "exact", head: true }).eq("trainer_id", trainer.id);
    if ((count ?? 0) > plan.max_students) {
      throw new HttpError(409, `Tenes ${count} alumnos y este plan permite ${plan.max_students}. Elegi un plan mayor.`);
    }
  }

  // Already live on this same plan?
  const { data: live } = await admin.from("trainer_subscriptions").select("id")
    .eq("payer_user_id", caller.userId).eq("source", "mp").eq("plan_id", plan.id)
    .in("status", ["authorized", "past_due", "paused"]).eq("is_active", true).limit(1);
  if (live?.length) throw new HttpError(409, "Ya tenes una suscripcion activa a este plan");

  // Rate limit: ALL source='mp' rows this payer created in the last hour, any
  // status (cancelled/failed attempts count too, so cancelling stale pendings
  // or failing the MP call can never reset the counter).
  const hourAgoIso = new Date(Date.now() - 3_600_000).toISOString();
  const { count: recent, error: recentErr } = await admin.from("trainer_subscriptions")
    .select("id", { count: "exact", head: true })
    .eq("payer_user_id", caller.userId).eq("source", "mp").gte("created_at", hourAgoIso);
  if (recentErr) throw new HttpError(503, "Error temporal, proba de nuevo");
  if ((recent ?? 0) >= 3) {
    throw new HttpError(429, "Hiciste demasiados intentos de suscripcion. Proba de nuevo en una hora");
  }

  // Abandoned checkouts: cancel stale pending rows (best effort on MP side).
  // Rows are kept (status cancelled), never deleted, so they stay in the count.
  const { data: pend } = await admin.from("trainer_subscriptions")
    .select("id, mp_preapproval_id").eq("payer_user_id", caller.userId)
    .eq("source", "mp").eq("status", "pending").limit(20);
  for (const p of pend ?? []) {
    if (p.mp_preapproval_id) {
      try {
        await mp("PUT", `/preapproval/${mpId(p.mp_preapproval_id)}`, { status: "cancelled" });
      } catch (e) {
        if (!(e instanceof MpError)) throw e; // already gone / non-cancellable: fine
      }
    }
    await admin.from("trainer_subscriptions")
      .update({ status: "cancelled", mp_status: "cancelled", is_active: false, canceled_at: new Date().toISOString() })
      .eq("id", p.id).eq("status", "pending");
  }

  // Insert the row FIRST (unique external_reference), then talk to MP, so a
  // crash can never leave an MP preapproval without a local row.
  const nonce = crypto.randomUUID().replace(/-/g, "").slice(0, 8);
  const externalReference = buildExternalReference(caller.userId, plan.id, nonce);
  const nowIso = new Date().toISOString();
  const { data: sub, error: insErr } = await admin.from("trainer_subscriptions").insert({
    trainer_id: trainer.id,
    payer_user_id: caller.userId,
    payer_type: "trainer",
    plan_id: plan.id,
    starts_at: nowIso,
    ends_at: nowIso,
    is_active: false,
    source: "mp",
    status: "pending",
    mp_status: "pending",
    mp_env: env,
    external_reference: externalReference,
    payer_email: payerEmail,
  }).select("id").single();
  if (insErr || !sub) throw new HttpError(500, "No se pudo iniciar la suscripcion");

  let createdPreapprovalId: string | null = null;
  try {
    const bound = await bindPayerToPlan({ plan, externalReference, payerEmail, env }, (id) => {
      createdPreapprovalId = id;
    });
    if (!bound.initPoint) throw new HttpError(502, "Mercado Pago no devolvio un link de pago");
    const { error: updErr } = await admin.from("trainer_subscriptions")
      .update({ mp_preapproval_id: bound.preapprovalId }).eq("id", sub.id);
    if (updErr) {
      console.error("mp-subscribe: link preapproval failed", updErr.code);
      throw new HttpError(500, "No se pudo iniciar la suscripcion");
    }
    return json(req, { init_point: bound.initPoint, subscription_id: sub.id });
  } catch (e) {
    // MP may already hold a preapproval nobody can pay: cancel it (best effort).
    if (createdPreapprovalId) {
      try {
        await mp("PUT", `/preapproval/${mpId(createdPreapprovalId)}`, { status: "cancelled" });
      } catch (ce) {
        console.error("mp-subscribe: orphan cancel failed", ce instanceof MpError ? `mp_${ce.status}` : "error");
      }
    }
    // Keep the row (cancelled) instead of deleting it so the attempt still counts
    // toward the rate limit.
    await admin.from("trainer_subscriptions")
      .update({ status: "cancelled", mp_status: "cancelled", is_active: false, canceled_at: new Date().toISOString() })
      .eq("id", sub.id).eq("status", "pending");
    if (e instanceof MpError) {
      console.error("mp-subscribe: MP error", e.status);
      // MP's validation messages (e.g. payer email not an MP user) are user-actionable.
      throw new HttpError(e.status >= 500 || e.status === 0 ? 502 : 422,
        e.status >= 500 || e.status === 0
          ? "Mercado Pago no esta disponible, proba de nuevo"
          : "Mercado Pago rechazo la solicitud. Verifica que el email sea el de tu cuenta de Mercado Pago");
    }
    throw e;
  }
});
