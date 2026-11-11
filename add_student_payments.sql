-- Migration: add monthly_fee to athletes + create student_payments table
-- Apply via Supabase MCP or SQL editor — do NOT run this in prod before review.

-- 1. Per-student monthly fee stored on the athlete row (trainer sets it once).
ALTER TABLE public.athletes
  ADD COLUMN IF NOT EXISTS monthly_fee numeric(12,2);

-- 2. Payment log table — trainer-internal, students must never read it.
CREATE TABLE IF NOT EXISTS public.student_payments (
  id          uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  trainer_id  uuid          NOT NULL REFERENCES public.trainers(id) ON DELETE CASCADE,
  athlete_id  uuid          NOT NULL REFERENCES public.athletes(id) ON DELETE CASCADE,
  amount      numeric(12,2) NOT NULL,
  paid_on     date          NOT NULL DEFAULT current_date,
  note        text,
  created_at  timestamptz   NOT NULL DEFAULT now()
);

-- Indexes for the monthly-earnings query (trainer + month) and per-athlete history.
CREATE INDEX IF NOT EXISTS idx_student_payments_trainer_paid_on
  ON public.student_payments (trainer_id, paid_on);

CREATE INDEX IF NOT EXISTS idx_student_payments_athlete_paid_on
  ON public.student_payments (athlete_id, paid_on);

-- 3. Enable RLS — no access without an explicit policy.
ALTER TABLE public.student_payments ENABLE ROW LEVEL SECURITY;

-- 4. Single ALL policy: only the owning trainer and admins.
--    Students are NEVER matched by either branch, so they get zero rows.
CREATE POLICY student_payments_trainer_or_admin
  ON public.student_payments
  FOR ALL
  USING (
    trainer_id = (SELECT private.my_trainer_id())
    OR (SELECT private.get_role()) = 'admin'
  )
  WITH CHECK (
    trainer_id = (SELECT private.my_trainer_id())
    OR (SELECT private.get_role()) = 'admin'
  );
