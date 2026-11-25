// Mercado Pago webhook receiver (public: verify_jwt = false).
// Pipeline: fail-closed secret check -> x-signature (HMAC, constant-time,
// timestamp tolerance) -> insert-first idempotency (mp_webhook_events.event_key)
// -> RE-FETCH the resource from MP with our token (the body is never trusted)
// -> match by external_reference -> upsert. 200 for handled/duplicate/permanent
// outcomes, 503 only for transient failures so MP retries.
import { getAdmin, json, mpEnv } from "../_shared/http.ts";
import { deriveEventKey, isMpId, resolveTopic, topicAttempts, verifyWebhookSignature } from "../_shared/logic.ts";
import { MpError } from "../_shared/mp.ts";
import { syncAuthorizedPayment, syncPayment, syncPreapproval } from "../_shared/billing.ts";
import { accountByMpUserId, getTrainerAccount } from "../_shared/mp_oauth.ts";
import { syncStudentAuthorizedPayment, syncStudentPreapproval } from "../_shared/student_billing.ts";

const MAX_BODY = 65_536;

const ok = (body: Record<string, unknown> = {}) => json(null, { ok: true, ...body }, 200);

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(null, { error: "Metodo no permitido" }, 405);

  // 1. Fail closed without a secret (MP will retry once it is configured).
  const secret = Deno.env.get("MP_WEBHOOK_SECRET");
  if (!secret) {
    console.error("mp-webhook: MP_WEBHOOK_SECRET not configured");
    return json(null, { error: "Webhook no configurado" }, 500);
  }

  let env: "test" | "prod";
  try {
    env = mpEnv();
  } catch {
    console.error("mp-webhook: MP_ENV invalid");
    return json(null, { error: "Webhook no configurado" }, 500);
  }

  // 2. Bounded body, signature BEFORE any parsing/DB work.
  const raw = await req.text();
  if (raw.length > MAX_BODY) return json(null, { error: "Demasiado grande" }, 413);

  const url = new URL(req.url);
  const dataId = url.searchParams.get("data.id");
  const requestId = req.headers.get("x-request-id");
  const tol = Number(Deno.env.get("MP_WEBHOOK_TOLERANCE_SECONDS") ?? 300);

  const sig = await verifyWebhookSignature({
    secret,
    signatureHeader: req.headers.get("x-signature"),
    requestId,
    dataId,
    nowMs: Date.now(),
    toleranceSeconds: Number.isFinite(tol) && tol > 0 ? tol : 300,
  });
  if (!sig.ok) {
    console.warn("mp-webhook: signature rejected", sig.reason);
    return json(null, { error: "Firma invalida" }, 401);
  }

  // 3. Parse (tolerant: the signature already vouches for id/ts/request-id).
  let body: Record<string, unknown> = {};
  try {
    const v = JSON.parse(raw);
    if (v && typeof v === "object" && !Array.isArray(v)) body = v;
  } catch { /* query-only notifications are fine */ }

  // Body type/entity is more accurate than the query (MP's simulator sends
  // mismatched ones). Both are untrusted: they only pick which endpoint the
  // signed id is re-fetched from.
  const topic = resolveTopic({
    bodyType: body.type,
    bodyEntity: body.entity,
    queryType: url.searchParams.get("type"),
    queryTopic: url.searchParams.get("topic"),
  });
  const action = String(body.action ?? "").slice(0, 64);
  const resourceId = dataId!.toLowerCase();
  if (!isMpId(resourceId)) return ok({ ignored: "bad_resource_id" });

  const eventKey = deriveEventKey({ env, topic, resourceId, requestId, ts: sig.ts });
  const admin = getAdmin();

  // 4. Insert-first idempotency. Trimmed payload: no PII.
  const ins = await admin.from("mp_webhook_events").insert({
    event_key: eventKey,
    topic,
    action,
    resource_id: resourceId,
    request_id: requestId?.slice(0, 128) ?? null,
    mp_env: env,
    payload: {
      type: body.type ?? null,
      action: body.action ?? null,
      data_id: resourceId,
      live_mode: body.live_mode ?? null,
      date_created: body.date_created ?? null,
    },
  }).select("id").maybeSingle();

  let eventId: string | undefined = ins.data?.id;
  if (ins.error) {
    if (ins.error.code !== "23505") {
      console.error("mp-webhook: event insert failed", ins.error.code);
      return json(null, { error: "Error temporal" }, 503);
    }
    // Duplicate delivery. No-op if already processed; if a previous attempt
    // failed mid-way, process again (the sync is idempotent).
    const { data: prev } = await admin.from("mp_webhook_events")
      .select("id, processed_at").eq("event_key", eventKey).maybeSingle();
    if (prev?.processed_at) return ok({ duplicate: true });
    eventId = prev?.id;
  }

  // 5. Dispatch. Everything below re-fetches from MP.
  try {
    let outcome = "ignored_topic";
    let usedTopic = topic;

    // Student billing: the notification belongs to a TRAINER's connected MP
    // account (body.user_id = the seller). The body is untrusted, so it only
    // selects whose token we re-fetch with; the resource itself must then
    // belong to that trainer (scoped by trainer_id in student_billing).
    const sellerId = body.user_id != null ? String(body.user_id) : "";
    const studentTrainerId = isMpId(sellerId) ? await accountByMpUserId(sellerId) : null;
    if (studentTrainerId) {
      const account = await getTrainerAccount(studentTrainerId);
      if (!account) outcome = "no_account";
      else if (topic === "subscription_preapproval") {
        outcome = (await syncStudentPreapproval(studentTrainerId, account.token, resourceId)).result;
      } else if (topic === "subscription_authorized_payment") {
        outcome = (await syncStudentAuthorizedPayment(studentTrainerId, account.token, resourceId)).result;
      }
      if (eventId) {
        await admin.from("mp_webhook_events").update({
          processed_at: new Date().toISOString(),
          error: outcome === "synced" ? null : outcome,
        }).eq("id", eventId);
      }
      return ok({ outcome: `student_${outcome}` });
    }

    // Bounded (max 2 fetches): an authorized_payment/payment topic carrying a
    // preapproval-shaped id is retried once as preapproval on MP 404.
    for (const t of topicAttempts(topic, resourceId)) {
      usedTopic = t;
      switch (t) {
        case "subscription_preapproval":
          outcome = (await syncPreapproval(resourceId)).result;
          break;
        case "subscription_authorized_payment":
          outcome = (await syncAuthorizedPayment(resourceId)).result;
          break;
        case "payment":
          outcome = (await syncPayment(resourceId)).result;
          break;
        default: // subscription_preapproval_plan, etc.: logged only
          outcome = "ignored_topic";
      }
      if (outcome !== "not_found") break;
    }
    if (eventId) {
      await admin.from("mp_webhook_events")
        .update({
          processed_at: new Date().toISOString(),
          error: outcome === "synced" ? null : outcome,
          topic: usedTopic, // event_key stays the delivery's original key
        })
        .eq("id", eventId);
    }
    return ok({ outcome });
  } catch (e) {
    const transient = !(e instanceof MpError) || e.transient;
    const msg = e instanceof MpError ? `mp_${e.status}` : (e instanceof Error ? e.message : "error").slice(0, 120);
    console.error("mp-webhook: processing failed", topic, msg);
    if (eventId) {
      await admin.from("mp_webhook_events").update({
        error: msg,
        // Permanent MP errors (4xx other than 404/400 handled upstream) are
        // closed so MP stops retrying; transient ones stay open for the retry.
        processed_at: transient ? null : new Date().toISOString(),
      }).eq("id", eventId);
    }
    return transient ? json(null, { error: "Error temporal" }, 503) : ok({ outcome: "permanent_error" });
  }
});
