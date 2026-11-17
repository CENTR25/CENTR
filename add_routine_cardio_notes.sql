-- Per-day cardio prescription text written by the trainer when "Cardio para
-- este día" is enabled. Keyed by the same day number stored in
-- routines.cardio_days, as a string: {"1": "20 min cinta inclinada", ...}.
-- RLS: covered by the existing row-level routines policies (scope_routines_rls.sql).
alter table public.routines
  add column if not exists cardio_notes jsonb not null default '{}'::jsonb;
