// Authenticated trainer: connect / disconnect their own Mercado Pago account.
//   { action: "start" }       -> { url }   (open it; MP redirects to mp-oauth-callback)
//   { action: "disconnect" }  -> { ok }
import { getAdmin, getCaller, HttpError, json, readJson, serveJson } from "../_shared/http.ts";
import { signState } from "../_shared/crypto.ts";
import { authorizationUrl } from "../_shared/mp_oauth.ts";

serveJson(async (req) => {
  const caller = await getCaller(req);
  if (caller.role !== "trainer") throw new HttpError(403, "Solo entrenadores");
  const admin = getAdmin();
  const { data: trainer } = await admin.from("trainers").select("id").eq("user_id", caller.userId).maybeSingle();
  if (!trainer) throw new HttpError(403, "Entrenador no encontrado");

  const body = await readJson(req);
  if (body.action === "start") {
    return json(req, { url: authorizationUrl(await signState(trainer.id)) });
  }
  if (body.action === "disconnect") {
    // Live student subscriptions keep running on MP, but we lose the token to
    // sync them; refuse while any is live so nothing is silently orphaned.
    const { count } = await admin.from("student_subscriptions").select("id", { count: "exact", head: true })
      .eq("trainer_id", trainer.id).in("status", ["pending", "authorized", "paused"]);
    if ((count ?? 0) > 0) {
      throw new HttpError(409, "Cancela las suscripciones activas de tus alumnos antes de desconectar");
    }
    await admin.from("trainer_mp_accounts").delete().eq("trainer_id", trainer.id);
    return json(req, { ok: true });
  }
  throw new HttpError(400, "Accion invalida");
});
