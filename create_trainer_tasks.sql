-- Trainer personal to-do / agenda items ("pendientes"): dated tasks a trainer
-- adds for themselves (e.g. "Armar dieta de alumno X", "Corregir", "Tomar
-- medidas"), optionally linked to a specific athlete. Surfaced on the trainer
-- home (today + overdue) and in the Agenda screen.

create table if not exists public.trainer_tasks (
  id          uuid primary key default gen_random_uuid(),
  trainer_id  uuid not null references public.trainers(id) on delete cascade,
  title       text not null,
  notes       text,
  due_date    date,
  is_done     boolean not null default false,
  athlete_id  uuid references public.athletes(id) on delete set null,
  created_at  timestamptz not null default now()
);

create index if not exists idx_trainer_tasks_trainer_due
  on public.trainer_tasks (trainer_id, due_date);

alter table public.trainer_tasks enable row level security;

-- Tasks are personal to each trainer: owner-only for every operation.
create policy trainer_tasks_select on public.trainer_tasks
  for select to authenticated
  using (trainer_id = (select private.my_trainer_id()));

create policy trainer_tasks_insert on public.trainer_tasks
  for insert to authenticated
  with check (trainer_id = (select private.my_trainer_id()));

create policy trainer_tasks_update on public.trainer_tasks
  for update to authenticated
  using (trainer_id = (select private.my_trainer_id()))
  with check (trainer_id = (select private.my_trainer_id()));

create policy trainer_tasks_delete on public.trainer_tasks
  for delete to authenticated
  using (trainer_id = (select private.my_trainer_id()));
