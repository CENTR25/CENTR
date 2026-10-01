-- Recurring weekly training slots per athlete, powering the trainer's weekly
-- "Horarios" agenda (e.g. "Juan entrena Lunes 08:00"). Slots repeat every week;
-- there is one row per athlete/day/time. start_time is local gym time.

create table if not exists public.athlete_training_schedule (
  id           uuid primary key default gen_random_uuid(),
  athlete_id   uuid not null references public.athletes(id) on delete cascade,
  day_of_week  smallint not null check (day_of_week between 0 and 6), -- 0=Mon .. 6=Sun
  start_time   time not null,
  notes        text,
  created_at   timestamptz not null default now()
);

create index if not exists idx_ats_athlete on public.athlete_training_schedule (athlete_id);

alter table public.athlete_training_schedule enable row level security;

-- Trainer manages the schedule of athletes that belong to them.
create policy ats_trainer_all on public.athlete_training_schedule
  for all to authenticated
  using (
    athlete_id in (
      select a.id from public.athletes a
      where a.trainer_id = (select private.my_trainer_id())
    )
    or (select private.get_role()) = 'admin'
  )
  with check (
    athlete_id in (
      select a.id from public.athletes a
      where a.trainer_id = (select private.my_trainer_id())
    )
    or (select private.get_role()) = 'admin'
  );

-- An athlete may read their own schedule.
create policy ats_athlete_read on public.athlete_training_schedule
  for select to authenticated
  using (athlete_id = (select private.my_athlete_id()));
