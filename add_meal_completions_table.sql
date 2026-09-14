-- Students can tick/confirm a meal as done for the day.
create table public.meal_completions (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  meal_plan_item_id uuid not null references public.meal_plan_items(id) on delete cascade,
  completed_on date not null default current_date,
  created_at timestamptz not null default now(),
  unique (athlete_id, meal_plan_item_id, completed_on)
);

alter table public.meal_completions enable row level security;

create policy "meal_completions_own" on public.meal_completions
  for all
  to authenticated
  using (athlete_id = (select private.my_athlete_id()))
  with check (athlete_id = (select private.my_athlete_id()));

create policy "meal_completions_trainer_read" on public.meal_completions
  for select
  to authenticated
  using (
    athlete_id in (
      select id from public.athletes
      where trainer_id = (select private.my_trainer_id())
    )
    or (select private.get_role()) = 'admin'
  );

create index idx_meal_completions_athlete_date
  on public.meal_completions (athlete_id, completed_on);
