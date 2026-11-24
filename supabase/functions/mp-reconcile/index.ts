// Drift repair: re-fetch non-final MP subscriptions and fix local state, then
// expire rows whose access window has passed. Gated by a shared cron secret
// (header x-cron-secret == CRON_SECRET env); fail closed if unset. Not callable
// by end users.
//
// Proposed schedule (NOT created; run in the SQL editor after setting secrets;
// store the secret in Vault, never inline):
//   select vault.create_secret('<CRON_SECRET value>', 'mp_cron_secret');
//   select cron.schedule('mp-reconcile-nightly', '17 6 * * *', $$
//     select net.http_post(
//       url := 'https://<project-ref>.supabase.co/functions/v1/mp-reconcile',
//       headers := jsonb_build_object(
//         'Content-Type', 'application/json',
//         'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'mp_cron_secret')),
//       body := '{}'::jsonb,
//       timeout_milliseconds := 55000);
//   $$);
import { constantTimeEqual, isAccessExpired, isRenewalOverdue } from "../_shared/logic.ts";
import { getAdmin, json, mpEnv } from "../_shared/http.ts";
import { MpError } from "../_shared/mp.ts";
import { syncPreapproval } from "../_shared/billing.ts";

const PENDING_ABANDON_MS = 2 * 86_400_000;

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(null, { error: "Metodo no permitido" }, 405);

  const secret = Deno.env.get("CRON_SECRET");
  if (!secret) {
    console.error("mp-reconcile: CRON_SECRET not configured");
    return json(null, { error: "No configurado" }, 500);
  }
  const given = req.headers.get("x-cron-secret") ?? "";
  if (!constantTimeEqual(given, secret)) return json(null, { error: "No autorizado" }, 401);

  const env = mpEnv();
  const admin = getAdmin();
  const now = new Date();

  // Oldest-synced first (updated_at is bumped by every sync), bounded batch.
  const { data: rows, error } = await admin.from("trainer_subscriptions")
    .select("id, status, ends_at, grace_until, mp_preapproval_id, created_at")
    .eq("source", "mp").eq("mp_env", env).not("mp_preapproval_id", "is", null)
    .in("status", ["pending", "authorized", "paused", "past_due", "cancelled"])
    .order("updated_at", { ascending: true })
    .limit(50);
  if (error) {
    console.error("mp-reconcile: select failed", error.code);
    return json(null, { error: "Error temporal" }, 503);
  }

  // Healthy 'authorized' rows whose ends_at already passed (late charge or a
  // dropped webhook): the oldest-synced batch above would never reach them.
  const { data: overdue, error: overdueErr } = await admin.from("trainer_subscriptions")
    .select("id, status, ends_at, grace_until, mp_preapproval_id, created_at")
    .eq("source", "mp").eq("mp_env", env).not("mp_preapproval_id", "is", null)
    .eq("status", "authorized").lt("ends_at", now.toISOString())
    .order("ends_at", { ascending: true })
    .limit(50);
  if (overdueErr) console.error("mp-reconcile: overdue select failed", overdueErr.code);

  const seen = new Set<string>();
  const batch = [...(rows ?? []), ...(overdue ?? []).filter((r) => isRenewalOverdue(r, now))]
    .filter((r) => (seen.has(r.id) ? false : (seen.add(r.id), true)));

  const summary = { checked: 0, synced: 0, not_found: 0, errors: 0, expired: 0, abandoned: 0 };
  for (const r of batch) {
    summary.checked++;
    try {
      const res = await syncPreapproval(r.mp_preapproval_id);
      if (res.result === "synced") summary.synced++;
      else if (res.result === "not_found") {
        summary.not_found++;
        // Pending preapproval MP no longer knows and older than 2 days: abandon.
        if (r.status === "pending" && Date.parse(r.created_at) < now.getTime() - PENDING_ABANDON_MS) {
          await admin.from("trainer_subscriptions")
            .update({ status: "cancelled", mp_status: "cancelled", is_active: false })
            .eq("id", r.id).eq("status", "pending").neq("source", "manual");
          summary.abandoned++;
        }
      }
    } catch (e) {
      summary.errors++;
      console.error("mp-reconcile: sync failed", e instanceof MpError ? `mp_${e.status}` : "error");
    }
  }

  // Close rows whose access window ended (cancelled/paused/past_due).
  // bounded: filtered to non-final MP rows, capped by .limit(200)
  const { data: open } = await admin.from("trainer_subscriptions")
    .select("id, status, ends_at, grace_until")
    .eq("source", "mp").in("status", ["cancelled", "paused", "past_due"]).limit(200);
  for (const r of open ?? []) {
    if (!isAccessExpired(r, now)) continue;
    const { error: e } = await admin.from("trainer_subscriptions")
      .update({ status: "expired", is_active: false })
      .eq("id", r.id).eq("source", "mp").in("status", ["cancelled", "paused", "past_due"]);
    if (!e) summary.expired++;
  }

  return json(null, { ok: true, ...summary });
});
