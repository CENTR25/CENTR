-- Applied to prod via Supabase MCP on 2026-09-20.
--
-- One-time "get to know the athlete" intake questionnaire, filled by the
-- student after onboarding and read by their trainer. Responses are stored as
-- jsonb keyed by the question keys defined in lib/core/constants/intake_form.dart
-- (single source of truth for the form and the trainer's read-only view).
create table if not exists public.athlete_intake (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null unique references public.athletes(id) on delete cascade,
  responses jsonb not null default '{}'::jsonb,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.athlete_intake enable row level security;

-- Student manages their own intake row.
drop policy if exists athlete_intake_own on public.athlete_intake;
create policy athlete_intake_own on public.athlete_intake
  for all to authenticated
  using (athlete_id = (select private.my_athlete_id()))
  with check (athlete_id = (select private.my_athlete_id()));

-- Trainer of the athlete (or admin) can read it.
drop policy if exists athlete_intake_staff_read on public.athlete_intake;
create policy athlete_intake_staff_read on public.athlete_intake
  for select to authenticated
  using (
    athlete_id in (
      select a.id from public.athletes a
      where a.trainer_id = (select private.my_trainer_id())
    )
    or (select private.get_role()) = 'admin'
  );

-- Second onboarding gate: the required intake questionnaire. Loaded into the
-- UserModel alongside has_completed_onboarding via profiles select(*).
alter table public.profiles
  add column if not exists has_completed_intake boolean not null default false;
