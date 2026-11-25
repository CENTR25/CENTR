-- Student access block: manual ("Bloquear acceso") + optional automatic cutoff
-- when the renewal date passes unpaid. Students are blocked, never deleted.
--
-- Blocked students keep their account and data; the app shows a "suspended"
-- screen until the trainer unblocks them (or a payment is recorded/detected).

ALTER TABLE public.athletes
  ADD COLUMN IF NOT EXISTS access_blocked boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS blocked_at timestamptz,
  ADD COLUMN IF NOT EXISTS block_reason text;

-- Per-trainer auto-cutoff settings. OFF by default.
ALTER TABLE public.trainers
  ADD COLUMN IF NOT EXISTS auto_block_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS auto_block_grace_days integer NOT NULL DEFAULT 3;

ALTER TABLE public.trainers
  DROP CONSTRAINT IF EXISTS trainers_auto_block_grace_days_check,
  ADD CONSTRAINT trainers_auto_block_grace_days_check
    CHECK (auto_block_grace_days BETWEEN 0 AND 30);

-- A student must never be able to unblock themselves or move their own due
-- date: reject those column changes when the caller is a student. Service-role
-- calls (Edge Functions) have no auth.uid() -> get_role() is NULL -> allowed.
CREATE OR REPLACE FUNCTION private.guard_athlete_billing_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF (SELECT private.get_role()) = 'student' AND (
       NEW.access_blocked  IS DISTINCT FROM OLD.access_blocked
    OR NEW.blocked_at      IS DISTINCT FROM OLD.blocked_at
    OR NEW.block_reason    IS DISTINCT FROM OLD.block_reason
    OR NEW.next_renewal_date IS DISTINCT FROM OLD.next_renewal_date
    OR NEW.monthly_fee     IS DISTINCT FROM OLD.monthly_fee
  ) THEN
    RAISE EXCEPTION 'students cannot change billing fields';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_athlete_billing_columns ON public.athletes;
CREATE TRIGGER trg_guard_athlete_billing_columns
  BEFORE UPDATE ON public.athletes
  FOR EACH ROW EXECUTE FUNCTION private.guard_athlete_billing_columns();

-- Same guard for the trainer-owned auto-block settings (trainer only / admin).
-- trainers is already trainer-writable; students have no write access to it.

-- The student asks "am I blocked?" through this function so the auto-cutoff
-- rule lives in ONE place (the DB), not duplicated in the client.
-- Returns no row when the caller is not a student.
CREATE OR REPLACE FUNCTION public.my_access_status()
RETURNS TABLE (blocked boolean, reason text, trainer_name text, auto boolean)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    (a.access_blocked
      OR (t.auto_block_enabled
          AND a.next_renewal_date IS NOT NULL
          AND a.next_renewal_date + t.auto_block_grace_days < current_date)
    ) AS blocked,
    CASE
      WHEN a.access_blocked THEN a.block_reason
      ELSE 'Tu cuota venció y no se registró el pago.'
    END AS reason,
    t.name AS trainer_name,
    (NOT a.access_blocked) AS auto
  FROM public.athletes a
  JOIN public.trainers t ON t.id = a.trainer_id
  WHERE a.user_id = (SELECT auth.uid());
$$;

REVOKE ALL ON FUNCTION public.my_access_status() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.my_access_status() TO authenticated;
