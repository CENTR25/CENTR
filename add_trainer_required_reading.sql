-- Per-trainer "Lectura Obligatoria" (mandatory reading) shown to that trainer's
-- athletes on their home screen. Nullable/empty means the trainer has none and
-- no banner is shown. Existing RLS already lets athletes SELECT trainers and
-- lets a trainer UPDATE their own row, so no policy changes are required.
alter table public.trainers
  add column if not exists required_reading text;
