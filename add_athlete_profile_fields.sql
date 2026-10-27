-- Profile screen ("Mi perfil") editable fields on the athlete's own row.
-- height_cm and goal already exist; weight is tracked in body_progress.
-- athletes_update RLS already allows self-update (user_id = auth.uid()), so no
-- policy change is needed — these are plain additive columns.

alter table public.athletes
  add column if not exists age integer,
  add column if not exists training_level text,
  add column if not exists injuries text,
  add column if not exists phone text,
  add column if not exists avatar_url text;
