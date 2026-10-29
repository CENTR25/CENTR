-- Structured cardio + supplements for the trainer Plan editors.
-- Additive & non-destructive: keeps legacy athletes.cardio_description /
-- cardio_days / daily_supplements / chemical_supplements intact.

-- ── Structured cardio fields on athletes ──────────────────────────────────
alter table public.athletes
  add column if not exists cardio_activity text,
  add column if not exists cardio_duration text,
  add column if not exists cardio_level text,
  add column if not exists cardio_note text;

-- ── Structured per-supplement model ───────────────────────────────────────
create table if not exists public.athlete_supplements (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  category text not null default 'diaria' check (category in ('diaria', 'quimica')),
  name text not null,
  dose text,
  unit text,                               -- g | mg | ml | caps
  timing text[] not null default '{}',     -- al_despertar, con_comidas, post_entreno, antes_dormir, pre_entreno
  days text not null default 'todos',      -- todos | entreno | medio
  note text,
  order_index integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_athlete_supplements_athlete
  on public.athlete_supplements(athlete_id);

alter table public.athlete_supplements enable row level security;

-- Athlete reads their own supplements (trainer sets them; athlete is read-only).
create policy athlete_supplements_own_read on public.athlete_supplements
  for select using (athlete_id = (select private.my_athlete_id()));

-- Trainer manages their own athletes' supplements.
create policy athlete_supplements_trainer_write on public.athlete_supplements
  for all
  using (athlete_id in (
    select id from public.athletes where trainer_id = (select private.my_trainer_id())
  ))
  with check (athlete_id in (
    select id from public.athletes where trainer_id = (select private.my_trainer_id())
  ));

-- Admin full access.
create policy athlete_supplements_admin_write on public.athlete_supplements
  for all
  using ((select private.get_role()) = 'admin')
  with check ((select private.get_role()) = 'admin');
