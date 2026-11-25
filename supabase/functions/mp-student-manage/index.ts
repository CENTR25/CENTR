// Authenticated trainer: cancel / pause / resume a student's subscription.
//   { action: "cancel"|"pause"|"resume", subscription_id: uuid } -> { ok, status }
import { getAdmin, getCaller, HttpError, json, readJson, serveJson } from "../_shared/http.ts";
import { isUuid } from "../_shared/logic.ts";
import { MpError, mpAs, mpId } from "../_shared/mp.ts";
import { getTrainerAccount } from "../_shared/mp_oauth.ts";
import { syncStudentPreapproval } from "../_shared/student_billing.ts";

const TARGET: Record<string, string> = { cancel: "cancelled", pause: "paused", resume: "authorized" };

serveJson(async (req) => {
  const caller = await getCaller(req);
  if (caller.role !== "trainer") throw new HttpError(403, "Solo entrenadores");
  const body = await readJson(req);
  const target = TARGET[String(body.action)];
  if (!target) throw new HttpError(400, "Accion invalida");
  if (!isUuid(body.subscription_id)) throw new HttpError(400, "subscription_id invalido");

  const admin = getAdmin();
  const { data: trainer } = await admin.from("trainers").select("id").eq("user_id", caller.userId).maybeSingle();
  if (!trainer) throw new HttpError(403, "Entrenador no encontrado");

  const { data: sub } = await admin.from("student_subscriptions")
    .select("id, mp_preapproval_id, status").eq("id", body.subscription_id).eq("trainer_id", trainer.id).maybeSingle();
  if (!sub?.mp_preapproval_id) throw new HttpError(404, "Suscripcion no encontrada");
  if (sub.status === "cancelled") throw new HttpError(409, "La suscripcion ya esta cancelada");

  const account = await getTrainerAccount(trainer.id);
  if (!account) throw new HttpError(409, "Conecta tu cuenta de Mercado Pago primero");

  try {
    await mpAs(account.token, "PUT", `/preapproval/${mpId(sub.mp_preapproval_id)}`, { status: target });
  } catch (e) {
    if (e instanceof MpError) throw new HttpError(422, "Mercado Pago rechazo el cambio");
    throw e;
  }
  await syncStudentPreapproval(trainer.id, account.token, sub.mp_preapproval_id);
  return json(req, { ok: true, status: target });
});
