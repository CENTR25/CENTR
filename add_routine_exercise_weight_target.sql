-- Per-set target weight for routine exercises (trainer-set targets).
-- Parallel to reps_target: a single value, or pipe-encoded per-set
-- (e.g. "92.5|85|80"). Nullable — athletes still log actual weights in set_logs.
alter table public.routine_exercises
  add column if not exists weight_target text;

comment on column public.routine_exercises.weight_target is
  'Trainer target weight(s) in kg. Single value or pipe-encoded per set, parallel to reps_target.';
