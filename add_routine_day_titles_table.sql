-- Per-day muscle-group titles for a routine (e.g. "Pecho Tríceps" for Monday).
-- day_number matches routine_exercises.day_number (1 = Monday .. 7 = Sunday).
-- One title per (routine, day). Shown to the student in the Entrenar day picker
-- and editable by the trainer in the routine editor.

create table if not exists public.routine_day_titles (
  id          uuid primary key default gen_random_uuid(),
  routine_id  uuid not null references public.routines(id) on delete cascade,
  day_number  int  not null,
  title       text not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (routine_id, day_number)
);

create index if not exists routine_day_titles_routine_id_idx
  on public.routine_day_titles (routine_id);

alter table public.routine_day_titles enable row level security;

-- Mirror routines / routine_exercises: a single permissive policy for
-- authenticated users. Access to a routine's titles follows the same posture
-- as the routine and its exercises.
drop policy if exists routine_day_titles_all on public.routine_day_titles;
create policy routine_day_titles_all
  on public.routine_day_titles
  for all
  to authenticated
  using (true)
  with check (true);
