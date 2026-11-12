-- Historical workout_sessions.started_at rows written by old app builds used an
-- offset-less local time (stored as UTC) => exactly 3h early on Argentina
-- devices. Evidence (2026-11-12): for completed sessions,
--   created_at - started_at - duration_seconds = 3.00h (constant) before ~Nov 3
-- and 0.00h after the UTC-write fix. created_at is DB-owned and correct.
-- Backfill: shift started_at +3h where that gap is 2.99h..3.6h (3h + small
-- pause drift). Idempotent: after the shift the gap becomes ~0 and no longer
-- matches. Ambiguous rows (gap ~4h, ~6h, ~24h = resumed drafts) are untouched.
UPDATE public.workout_sessions
SET started_at = started_at + interval '3 hours'
WHERE is_completed
  AND duration_seconds IS NOT NULL
  AND created_at - started_at - make_interval(secs => duration_seconds)
      BETWEEN interval '2 hours 59 minutes' AND interval '3 hours 36 minutes';
