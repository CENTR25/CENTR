// Admin-only: create/sync Mercado Pago preapproval_plans from subscription_plans.
//   { action: "sync_plans", plan_id?: uuid }   idempotent create / price+name sync
//   { action: "deactivate_plan", plan_id: uuid }  stop new signups for a plan
// The price always comes from the DB row, never from the request.
import { getAdmin, HttpError, json, mpEnv, readJson, requireAdmin, requireEnv, serveJson } from "../_shared/http.ts";
import { isUuid } from "../_shared/logic.ts";
import { MpError, mp, mpId, safeInitPoint } from "../_shared/mp.ts";

// deno-lint-ignore no-explicit-any
type Row = Record<string, any>;

const backUrl = () => Deno.env.get("BILLING_BACK_URL") ?? "https://prgs.app/billing/return";

function desired(plan: Row, env: string) {
  const prefix = env === "test" ? "[TEST] " : "";
  return {
    reason: `${prefix}PRGS ${plan.name}${plan.max_students ? ` (${plan.max_students} alumnos)` : ""}`.slice(0, 200),
    amount: Number(plan.price),
    currency: String(plan.currency_id ?? "ARS"),
    frequency: Number(plan.frequency ?? 1),
    frequencyType: String(plan.frequency_type ?? "months"),
  };
}

async function syncOne(plan: Row, env: "test" | "prod") {
  const d = desired(plan, env);
  if (plan.price_is_placeholder) return { plan_id: plan.id, result: "skipped_placeholder_price" };
  if (!Number.isFinite(d.amount) || d.amount <= 0) return { plan_id: plan.id, result: "skipped_invalid_price" };
  const autoRecurring = {
    frequency: d.frequency,
    frequency_type: d.frequencyType,
    transaction_amount: d.amount,
    currency_id: d.currency,
  };
  const admin = getAdmin();

  const create = async () => {
    const created = await mp<Row>("POST", "/preapproval_plan", {
      reason: d.reason,
      auto_recurring: autoRecurring,
      back_url: backUrl(),
    }, `plan-${plan.id}-${env}-${d.amount}`);
    const initPoint = safeInitPoint(created.init_point);
    if (!created.id || !initPoint) throw new HttpError(502, "Respuesta invalida de Mercado Pago");
    const { error } = await admin.from("subscription_plans").update({
      mp_plan_id: String(created.id),
      mp_init_point: initPoint,
      mp_env: env,
      is_active: true,
    }).eq("id", plan.id);
    if (error) {
      console.error("mp-admin: db update failed after MP create", plan.id, String(created.id));
      throw new HttpError(500, "No se pudo guardar el plan (id MP en logs)");
    }
    return { plan_id: plan.id, result: "created", mp_plan_id: String(created.id) };
  };

  if (!plan.mp_plan_id || plan.mp_env !== env) return await create();

  // Already linked in this env: read, then PUT only if something differs.
  let remote: Row;
  try {
    remote = await mp<Row>("GET", `/preapproval_plan/${mpId(plan.mp_plan_id)}`);
  } catch (e) {
    if (e instanceof MpError && e.status === 404) return await create();
    throw e;
  }
  const ar = (remote.auto_recurring ?? {}) as Row;
  const same = Number(ar.transaction_amount) === d.amount && ar.currency_id === d.currency &&
    Number(ar.frequency) === d.frequency && ar.frequency_type === d.frequencyType &&
    remote.reason === d.reason && remote.status === "active";
  if (same) {
    if (!plan.is_active) await admin.from("subscription_plans").update({ is_active: true }).eq("id", plan.id);
    return { plan_id: plan.id, result: "unchanged", mp_plan_id: plan.mp_plan_id };
  }
  // NOTE: MP docs say plan edits do not change existing subscriptions.
  await mp("PUT", `/preapproval_plan/${mpId(plan.mp_plan_id)}`, {
    reason: d.reason,
    auto_recurring: autoRecurring,
    status: "active",
  });
  await admin.from("subscription_plans").update({ is_active: true }).eq("id", plan.id);
  return { plan_id: plan.id, result: "updated", mp_plan_id: plan.mp_plan_id };
}

serveJson(async (req) => {
  await requireAdmin(req);
  requireEnv("MP_ACCESS_TOKEN");
  const env = mpEnv();
  const body = await readJson(req);
  const action = body.action;
  const admin = getAdmin();

  if (action === "sync_plans") {
    // bounded: a handful of plans, capped with .limit(20) below
    let q = admin.from("subscription_plans").select("*").eq("audience", "trainer");
    if (body.plan_id !== undefined) {
      if (!isUuid(body.plan_id)) throw new HttpError(400, "plan_id invalido");
      q = q.eq("id", body.plan_id);
    }
    const { data: plans, error } = await q.order("price", { ascending: true }).limit(20);
    if (error) throw new HttpError(500, "Error de base de datos");
    if (!plans?.length) throw new HttpError(404, "No hay planes para sincronizar");
    const results = [];
    for (const p of plans) {
      try {
        results.push(await syncOne(p, env));
      } catch (e) {
        console.error("mp-admin: plan sync failed", p.id, e instanceof MpError ? `mp_${e.status}` : "error");
        results.push({ plan_id: p.id, result: "error", error: e instanceof MpError ? `mp_${e.status}` : "error" });
      }
    }
    return json(req, { env, results });
  }

  if (action === "deactivate_plan") {
    if (!isUuid(body.plan_id)) throw new HttpError(400, "plan_id invalido");
    const { data: plan } = await admin.from("subscription_plans").select("id, mp_plan_id, mp_env").eq("id", body.plan_id).maybeSingle();
    if (!plan) throw new HttpError(404, "Plan no encontrado");
    if (plan.mp_plan_id && plan.mp_env === env) {
      await mp("PUT", `/preapproval_plan/${mpId(plan.mp_plan_id)}`, { status: "inactive" });
    }
    await admin.from("subscription_plans").update({ is_active: false }).eq("id", plan.id);
    return json(req, { ok: true });
  }

  throw new HttpError(400, "Accion desconocida");
});
