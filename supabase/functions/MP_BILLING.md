# Mercado Pago billing Edge Functions

Trainers pay PRGS monthly (ARS) via MP subscriptions (preapproval). Students never pay.
Payer-agnostic: rows carry `payer_user_id` + `payer_type`.

| Function | Caller | Purpose |
|---|---|---|
| `mp-admin` | admin JWT | create/sync MP `preapproval_plan` from `subscription_plans` (`sync_plans`, `deactivate_plan`) |
| `mp-subscribe` | trainer JWT | create a pending preapproval, return `init_point` (Option A binding, isolated in `bindPayerToPlan`) |
| `mp-webhook` | public (MP) | verify signature, insert-first idempotency, re-fetch from MP, upsert state |
| `mp-manage` | payer JWT (or admin) | `cancel` / `pause` / `resume` own subscription |
| `mp-reconcile` | cron secret | re-sync non-final subscriptions, expire lapsed access |

Shared code lives in `_shared/` (`logic.ts` = pure, unit tested; `mp.ts` = MP client; `billing.ts` = sync; `http.ts` = auth/CORS).
All five functions use `verify_jwt = false` (see each `config.toml`) and authenticate in code (same convention as `admin-auth`).
**Deploy with `verify_jwt:false` passed explicitly** (the MCP deploy tool defaults to true, which would block MP's webhook). Prefer `supabase functions deploy <name> --no-verify-jwt` so `_shared/` is bundled; with the MCP tool every function must include the `_shared/*.ts` files.

## Secrets (Supabase Edge Function secrets only; never in repo/Flutter/logs)
| Name | Notes |
|---|---|
| `MP_ACCESS_TOKEN` | seller access token for the current env |
| `MP_WEBHOOK_SECRET` | "Clave secreta" of the webhook config (test and prod differ) |
| `MP_ENV` | `test` or `prod` (rows/plans are tagged with it; mismatches are ignored) |
| `CRON_SECRET` | random string; only `mp-reconcile` |
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | injected by Supabase |
| optional `ALLOWED_ORIGINS` | CORS allow-list, default `https://prgs.app` (localhost allowed only when `MP_ENV=test`) |
| optional `BILLING_BACK_URL` | default `https://prgs.app/billing/return` |
| optional `MP_GRACE_DAYS` (5), `MP_WEBHOOK_TOLERANCE_SECONDS` (300) | |

Set with: `supabase secrets set MP_ENV=test` (read the token/secret from your secret store, do not paste into chat or files).

## Unit tests
`cd supabase/functions/_shared && deno test logic_test.ts` (pure logic: signature, status mapping, event key, validators).

## Smoke tests
Set `REF=<project-ref>`, `FN=https://$REF.supabase.co/functions/v1`, `ANON=<anon key>`, `ADMIN_JWT`, `TRAINER_JWT` (user access tokens from a login), `PLAN_ID=<uuid>`.

```bash
# Auth gates (all must be 401/403)
curl -s -X POST $FN/mp-admin     -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -d '{"action":"sync_plans"}'
curl -s -X POST $FN/mp-subscribe -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -d '{}'
curl -s -X POST $FN/mp-manage    -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -d '{}'
curl -s -X POST $FN/mp-reconcile -d '{}'                                  # 401 (no x-cron-secret)

# Webhook: forged / missing signature -> 401
curl -s -i -X POST "$FN/mp-webhook?data.id=123&type=payment" -H "x-request-id: t1" \
  -H "x-signature: ts=$(date +%s),v1=$(printf 'a%.0s' {1..64})" -d '{}'

# Create/sync the MP plans (admin, MP_ENV=test)
curl -s -X POST $FN/mp-admin -H "Authorization: Bearer $ADMIN_JWT" -H "apikey: $ANON" \
  -d '{"action":"sync_plans"}'                                              # run twice: second = "unchanged"

# Subscribe (trainer; payer_email = MP test BUYER account email, never the seller)
curl -s -X POST $FN/mp-subscribe -H "Authorization: Bearer $TRAINER_JWT" -H "apikey: $ANON" \
  -d "{\"plan_id\":\"$PLAN_ID\",\"payer_email\":\"<test-buyer-email>\"}"    # -> {init_point, subscription_id}
# open init_point as the test buyer, pay with card holder name APRO (see tasks/mp-phase0-findings.md)

# Valid signed webhook (computes the HMAC locally; secret from your shell env, not the repo)
TS=$(date +%s); RID=$(uuidgen); DID=<preapproval_id>
SIG=$(printf "id:$(echo $DID | tr A-Z a-z);request-id:$RID;ts:$TS;" | openssl dgst -sha256 -hmac "$MP_WEBHOOK_SECRET" -hex | awk '{print $NF}')
curl -s -i -X POST "$FN/mp-webhook?data.id=$DID&type=subscription_preapproval" \
  -H "x-request-id: $RID" -H "x-signature: ts=$TS,v1=$SIG" -d '{"action":"updated","type":"subscription_preapproval"}'
# repeat the exact same call -> {"ok":true,"duplicate":true}

# Cancel / pause / resume
curl -s -X POST $FN/mp-manage -H "Authorization: Bearer $TRAINER_JWT" -H "apikey: $ANON" \
  -d '{"action":"cancel","subscription_id":"<uuid>"}'

# Reconcile
curl -s -X POST $FN/mp-reconcile -H "x-cron-secret: $CRON_SECRET" -d '{}'
```
Nightly pg_cron job `mp-reconcile-nightly` (06:00 UTC) is defined in `add_mp_reconcile_cron.sql`; it reads vault secret `mp_cron_secret`, which must equal the `CRON_SECRET` Edge Function secret.

## Behaviour notes
- Test buyers: the MP test buyer's email follows `test_user_<digits of its nickname>@testuser.com` (e.g. nickname `TESTUSER123456` -> `test_user_123456@testuser.com`). Use that as `payer_email` in `mp-subscribe`, never the seller's.
- Price changes need a NEW plan (new `subscription_plans` row), not an edit: existing MP subscribers keep the price they subscribed at (per MP docs). Deactivate the old plan (`is_active=false`) so it is no longer offered.
- Option A (current) never uses `mp_plan_id` or `sync_plans`; `mp-subscribe` only needs an active trainer plan with a valid price. Those only matter if switching to Option B.
- `payer_email` is write-once: MP returns `""` on preapproval fetch, so sync only backfills it when the column is empty and MP gives a valid email (`payerEmailToBackfill`); it is never blanked or overwritten.
- Access is only ever granted by the webhook/reconcile after re-fetching from MP; `mp-subscribe` inserts `pending`/`is_active=false`.
- `external_reference = "<payer_user_id>:<plan_id>:<nonce8>"` (nonce lets a payer re-subscribe after cancelling; cancelled preapprovals cannot be reactivated and the column is unique).
- Renewal buffer: `private.billing_student_cap` keeps access 24h past `ends_at` for `source='mp'` rows in `authorized` status only (`add_mp_renewal_buffer.sql`), so a late charge/webhook does not cut access. Manual rows and other states are unchanged. `mp-reconcile` also re-syncs `authorized` MP rows whose `ends_at` already passed (separate batch of 50, oldest first).
- Grace is ONLY for failed charges: healthy `authorized` rows have `grace_until = NULL` (cleared on recovery) and access ends exactly at `ends_at` (= MP `next_payment_date`; a successful charge moves it forward via sync, a failed one opens `past_due`). `private.billing_student_cap` uses `greatest(ends_at, grace_until)`, so a non-null grace on a healthy row would hand out free days.
- Every preapproval sync also reads `GET /authorized_payments/search?preapproval_id=<id>&limit=50` and upserts each non-scheduled charge into `mp_payments` (unique on `mp_payment_id` = MP payment id, or `ap-<authorized_payment id>`). Best-effort: failures log `sync_charges_failed` and never undo the subscription sync. Only the first 50 charges are read.
- Failed charge on a previously paid sub -> `past_due`, `grace_until = now + 5d`; first-charge failure never grants access. Cancelled/paused keep access to `ends_at`; reconcile marks them `expired` afterwards. `source='manual'` rows are never modified.
- Upgrades (server-side, no client needed): when `syncPreapproval` sees a row become `authorized` for the first time WITH payment evidence (no prior `last_payment_at`), it cancels the same payer's other live `source='mp'` rows (authorized/pending/paused/past_due, other `mp_preapproval_id`, same `mp_env`, never manual) via MP `PUT cancelled` and re-syncs them (access kept until their `ends_at`, like `mp-manage`). Only rows created BEFORE the newly paid one are retired, so two concurrent activations cannot cancel each other; max 5 per run; failures log short codes (`supersede_*`) and never undo the new sub's sync. Idempotent. The client's `mp-manage cancel` call remains a harmless fallback. Re-subscribing to the same plan after cancel is unaffected (cancelled rows are not live). Residual: a NEWER pending checkout of the same payer that is paid later is not auto-retired.
- First-charge access: `is_active` is never granted on first activation without payment evidence = approved authorized_payment (passed in by the webhook or found via `/authorized_payments/search`), approved `mp_payments` row, `summarized.charged_quantity > 0`, or `summarized.last_charged_date`. `neverPaid` = no evidence AND no `last_payment_at` (not "status pending"). MP `authorized` without evidence stays `pending`/inactive (mp_status keeps `authorized`); the charge webhook or `mp-reconcile` promotes it. A failed first charge never grants access and never starts the 5-day grace.
- `mp-subscribe` rate limit: counts ALL `source='mp'` rows by the payer created in the last hour (any status); >= 3 -> 429 (Spanish message). Stale pending rows are cancelled (not deleted) and failed attempts are marked `cancelled` instead of deleted, so neither resets the counter.
- `mp-subscribe` orphan handling: once MP returns a preapproval id, any later failure (no safe `init_point`, failed `mp_preapproval_id` update, etc.) best-effort cancels that preapproval on MP (`mp-subscribe: orphan cancel failed <code>` if even that fails; reconcile abandons stale pendings).
- Webhook dedupe key = `<env>|<resolved topic>|<data.id lowercased>|r:<x-request-id>` (or `t:<ts>` without a request id). The unsigned body `action` (and any other body field) no longer participates. Old 5-part keys stay in the table; only new events use the new shape (an old in-flight retry may be processed once more, which is idempotent).
- Retention: `add_mp_webhook_events_retention.sql` schedules pg_cron `mp-webhook-events-retention` daily 07:00 UTC deleting `mp_webhook_events` rows with `received_at` older than 90 days (no secrets; unschedules the same-named job first).
- Webhook signature requires `data.id` in the query string (it is what the HMAC covers); notifications without it get 401.
- Needs live verification: `init_point` returned for a standalone pending preapproval, payer_email must be an MP user, real payload shapes for `authorized_payment` / `payment`, test-mode `ts` tolerance for simulated notifications.
