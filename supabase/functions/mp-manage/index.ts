// Authenticated payer: manage their own subscription.
//   { action: "cancel" | "pause" | "resume", subscription_id: uuid }
// Cancel keeps access until the paid-through date (ends_at). Admins may act on
// any MP-sourced row. Manual (comp) rows are never touched.
import { getAdmin, getCaller, HttpError, json, mpEnv, readJson, requireEnv, serveJson } from "../_shared/http.ts";
import { isUuid } from "../_shared/logic.ts";
import { MpError, mp, mpId } from "../_shared/mp.ts";
import { syncPreapproval } from "../_shared/billing.ts";

const TARGET: Record<string, string> = { cancel: "cancelled", pause: "paused", resume: "authorized" };

serveJson(async (req) => {
  const caller = await getCaller(req);
  requireEnv("MP_ACCESS_TOKEN");
  const env = mpEnv();
  const body = await readJson(req);

  const action = String(body.action ?? "");
  if (!(action in TARGET)) throw new HttpError(400, "Accion desconocida");
  if (!isUuid(body.subscription_id)) throw new HttpError(400, "subscription_id invalido");

  const admin = getAdmin();
  const { data: sub } = await admin.from("trainer_subscriptions")
    .select("id, source, status, payer_user_id, mp_preapproval_id, mp_env")
    .eq("id", body.subscription_id).maybeSingle();

  // Same answer for "missing" and "not yours" (no enumeration).
  if (!sub || (sub.payer_user_id !== caller.userId && caller.role !== "admin")) {
    throw new HttpError(404, "Suscripcion no encontrada");
  }
  if (sub.source !== "mp" || !sub.mp_preapproval_id) {
    throw new HttpError(409, "Esta suscripcion no se administra desde Mercado Pago");
  }
  if (sub.mp_env !== env) throw new HttpError(409, "Suscripcion de otro entorno");
  if (["cancelled", "expired"].includes(sub.status)) {
    throw new HttpError(409, "La suscripcion ya esta cancelada");
  }
  if (action === "pause" && sub.status !== "authorized") throw new HttpError(409, "Solo se puede pausar una suscripcion activa");
  if (action === "resume" && sub.status !== "paused") throw new HttpError(409, "La suscripcion no esta pausada");

  try {
    await mp("PUT", `/preapproval/${mpId(sub.mp_preapproval_id)}`, { status: TARGET[action] });
  } catch (e) {
    if (e instanceof MpError) {
      console.error("mp-manage: MP error", action, e.status);
      throw new HttpError(e.status >= 500 || e.status === 0 ? 502 : 422, "Mercado Pago no pudo procesar el cambio");
    }
    throw e;
  }

  // Re-fetch and mirror MP's real state (also covers MP rejecting silently).
  const res = await syncPreapproval(sub.mp_preapproval_id);
  if (res.result !== "synced") throw new HttpError(502, "No se pudo confirmar el estado");
  return json(req, { ok: true, status: res.status });
});
