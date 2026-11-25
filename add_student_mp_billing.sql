-- Trainers connect THEIR OWN Mercado Pago account (OAuth) and bill their
-- students with auto-recurring subscriptions that land in the trainer's
-- account. PRGS takes no commission. Separate from the trainer->PRGS billing
-- (trainer_subscriptions / mp_payments).
--
-- Depends on: add_student_payments.sql, add_student_access_block.sql.

-- 1. Connected MP accounts. Tokens are AES-GCM encrypted by the Edge Function
--    (MP_TOKEN_ENC_KEY) before they are stored. RLS is ON with NO policies:
--    only the service role can touch this table; clients never read tokens.
CREATE TABLE IF NOT EXISTS public.trainer_mp_accounts (
  trainer_id     uuid PRIMARY KEY REFERENCES public.trainers(id) ON DELETE CASCADE,
  mp_user_id     text NOT NULL,
  mp_env         text NOT NULL CHECK (mp_env IN ('test', 'prod')),
  access_token   text NOT NULL,   -- encrypted
  refresh_token  text NOT NULL,   -- encrypted
  expires_at     timestamptz NOT NULL,
  connected_at   timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS trainer_mp_accounts_mp_user_env
  ON public.trainer_mp_accounts (mp_user_id, mp_env);
ALTER TABLE public.trainer_mp_accounts ENABLE ROW LEVEL SECURITY;

-- Safe status for the trainer UI (no tokens).
CREATE OR REPLACE FUNCTION public.my_mp_connection()
RETURNS TABLE (connected boolean, connected_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT true, a.connected_at
  FROM public.trainer_mp_accounts a
  WHERE a.trainer_id = (SELECT private.my_trainer_id());
$$;
REVOKE ALL ON FUNCTION public.my_mp_connection() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.my_mp_connection() TO authenticated;

-- 2. One row per student subscription created on a trainer's MP account.
CREATE TABLE IF NOT EXISTS public.student_subscriptions (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trainer_id        uuid NOT NULL REFERENCES public.trainers(id) ON DELETE CASCADE,
  athlete_id        uuid NOT NULL REFERENCES public.athletes(id) ON DELETE CASCADE,
  mp_env            text NOT NULL CHECK (mp_env IN ('test', 'prod')),
  mp_preapproval_id text UNIQUE,
  external_reference text NOT NULL UNIQUE,   -- student:<athlete_id>:<nonce>
  status            text NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'authorized', 'paused', 'cancelled')),
  amount            numeric(12,2) NOT NULL CHECK (amount > 0),
  payer_email       text NOT NULL,
  init_point        text,
  next_payment_date timestamptz,
  last_payment_at   timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_student_subscriptions_athlete
  ON public.student_subscriptions (athlete_id, created_at DESC);
ALTER TABLE public.student_subscriptions ENABLE ROW LEVEL SECURITY;

-- Trainer reads their own rows (and admin all). Writes: service role only.
DROP POLICY IF EXISTS student_subscriptions_trainer_read ON public.student_subscriptions;
CREATE POLICY student_subscriptions_trainer_read ON public.student_subscriptions
  FOR SELECT TO authenticated
  USING (
    trainer_id = (SELECT private.my_trainer_id())
    OR (SELECT private.get_role()) = 'admin'
  );

-- 3. Payments detected from MP land in student_payments, idempotent per MP id.
ALTER TABLE public.student_payments
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS mp_payment_id text;
CREATE UNIQUE INDEX IF NOT EXISTS student_payments_mp_payment_id
  ON public.student_payments (mp_payment_id) WHERE mp_payment_id IS NOT NULL;
