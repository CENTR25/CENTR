// Authenticated trainer: create an auto-recurring subscription for ONE of
// their students on the trainer's own connected Mercado Pago account.
//   { athlete_id: uuid, payer_email?: string } -> { init_point, subscription_id }
// The amount is athletes.monthly_fee (never taken from the client). The row is
// inserted first, then MP is called; access/dates change only via the webhook.
import { getAdmin, getCaller, HttpError, json, mpEnv, readJson, serveJson } from "../_shared/http.ts";
import { isEmail, isUuid } from "../_shared/logic.ts";
import { MpError, mpAs, mpId, safeInitPoint } from "../_shared/mp.ts";
import { getTrainerAccount } from "../_shared/mp_oauth.ts";
import { buildStudentReference } from "../_shared/student_billing.ts";

// deno-lint-ignore no-explicit-any
type Row = Record<string, any>;
const backUrl = () => Deno.env.get("BILLING_BACK_URL") ?? "https://prgs.app/billing/return";

serveJson(async (req) => {
  const caller = await getCaller(req);
  if (caller.role !== "trainer") throw new HttpError(403, "Solo entrenadores");
  const env = mpEnv();
  const body = await readJson(req);
  if (!isUuid(body.athlete_id)) throw new HttpError(400, "athlete_id invalido");

  const admin = getAdmin();
  const { data: trainer } = await admin.from("trainers").select("id, name").eq("user_id", caller.userId).maybeSingle();
  if (!trainer) throw new HttpError(403, "Entrenador no encontrado");

  const account = await getTrainerAccount(trainer.id);
  if (!account) throw new HttpError(409, "Conecta tu cuenta de Mercado Pago primero");

  // The student must belong to THIS trainer.
  const { data: athlete } = await admin.from("athletes")
    .select("id, name, user_id, monthly_fee").eq("id", body.athlete_id).eq("trainer_id", trainer.id).maybeSingle();
  if (!athlete) throw new HttpError(404, "Alumno no encontrado");
  const amount = Number(athlete.monthly_fee);
  if (!(amount > 0)) throw new HttpError(409, "Carga primero la cuota mensual del alumno");

  let payerEmail = typeof body.payer_email === "string" ? body.payer_email.trim().toLowerCase() : "";
  if (!payerEmail) {
    const { data: prof } = await admin.from("profiles").select("email").eq("id", athlete.user_id).maybeSingle();
    payerEmail = String(prof?.email ?? "").toLowerCase();
  }
  if (!isEmail(payerEmail)) throw new HttpError(400, "Ingresa el email de Mercado Pago del alumno");

  const { data: live } = await admin.from("student_subscriptions").select("id")
    .eq("athlete_id", athlete.id).in("status", ["authorized", "paused"]).limit(1);
  if (live?.length) throw new HttpError(409, "El alumno ya tiene una suscripcion activa");

  // Rate limit: 5 attempts / hour / student (cancelled attempts still count).
  const hourAgo = new Date(Date.now() - 3_600_000).toISOString();
  const { count: recent } = await admin.from("student_subscriptions")
    .select("id", { count: "exact", head: true }).eq("athlete_id", athlete.id).gte("created_at", hourAgo);
  if ((recent ?? 0) >= 5) throw new HttpError(429, "Demasiados intentos. Proba de nuevo en una hora");

  // Retire stale pending checkouts for this student (rows kept, status cancelled).
  const { data: pend } = await admin.from("student_subscriptions")
    .select("id, mp_preapproval_id").eq("athlete_id", athlete.id).eq("status", "pending").limit(10);
  for (const p of pend ?? []) {
    if (p.mp_preapproval_id) {
      try {
        await mpAs(account.token, "PUT", `/preapproval/${mpId(p.mp_preapproval_id)}`, { status: "cancelled" });
      } catch (e) {
        if (!(e instanceof MpError)) throw e;
      }
    }
    await admin.from("student_subscriptions").update({ status: "cancelled" }).eq("id", p.id).eq("status", "pending");
  }

  const nonce = crypto.randomUUID().replace(/-/g, "").slice(0, 8);
  const externalReference = buildStudentReference(athlete.id, nonce);
  const { data: sub, error: insErr } = await admin.from("student_subscriptions").insert({
    trainer_id: trainer.id,
    athlete_id: athlete.id,
    mp_env: env,
    external_reference: externalReference,
    status: "pending",
    amount,
    payer_email: payerEmail,
  }).select("id").single();
  if (insErr || !sub) throw new HttpError(500, "No se pudo iniciar la suscripcion");

  let createdId: string | null = null;
  try {
    const prefix = env === "test" ? "[TEST] " : "";
    const created = await mpAs<Row>(account.token, "POST", "/preapproval", {
      reason: `${prefix}Cuota mensual - ${trainer.name ?? "Entrenador"}`.slice(0, 200),
      external_reference: externalReference,
      payer_email: payerEmail,
      back_url: backUrl(),
      status: "pending",
      auto_recurring: {
        frequency: 1,
        frequency_type: "months",
        transaction_amount: amount,
        currency_id: "ARS",
      },
    }, externalReference);
    if (!created.id) throw new HttpError(502, "Respuesta invalida de Mercado Pago");
    createdId = String(created.id);
    const initPoint = safeInitPoint(created.init_point);
    if (!initPoint) throw new HttpError(502, "Mercado Pago no devolvio un link de pago");
    const { error: updErr } = await admin.from("student_subscriptions")
      .update({ mp_preapproval_id: createdId, init_point: initPoint }).eq("id", sub.id);
    if (updErr) throw new HttpError(500, "No se pudo iniciar la suscripcion");
    return json(req, { init_point: initPoint, subscription_id: sub.id });
  } catch (e) {
    if (createdId) {
      try {
        await mpAs(account.token, "PUT", `/preapproval/${mpId(createdId)}`, { status: "cancelled" });
      } catch { /* best effort */ }
    }
    await admin.from("student_subscriptions").update({ status: "cancelled" }).eq("id", sub.id).eq("status", "pending");
    if (e instanceof MpError) {
      console.error("mp-student-subscribe: MP error", e.status);
      throw new HttpError(
        e.status >= 500 || e.status === 0 ? 502 : 422,
        e.status >= 500 || e.status === 0
          ? "Mercado Pago no esta disponible, proba de nuevo"
          : "Mercado Pago rechazo la solicitud. Verifica el email de Mercado Pago del alumno",
      );
    }
    throw e;
  }
});
