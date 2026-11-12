-- Scope meal plan RLS (replaces ALL ... USING (true) on meal_plans,
-- meal_plan_items, athlete_meal_plans, which let any authenticated user —
-- students included — read/edit/delete every trainer's plans).
--
-- Access model:
--   meal_plans / meal_plan_items
--     read : owning trainer, admin, or a student with an assignment to the plan
--     write: owning trainer, admin
--   athlete_meal_plans
--     read : the student themself, the student's trainer, admin
--     write: the student's trainer (and only for plans that trainer owns), admin
--
-- Helpers are SECURITY DEFINER so policies don't recurse through each
-- other's RLS (meal_plans <-> athlete_meal_plans <-> athletes).

create or replace function private.owns_meal_plan(p_plan_id uuid)
returns boolean language sql stable security definer set search_path to ''
as $$
  select exists (
    select 1 from public.meal_plans mp
    where mp.id = p_plan_id
      and mp.trainer_id = (select private.my_trainer_id())
  );
$$;

create or replace function private.can_read_meal_plan(p_plan_id uuid)
returns boolean language sql stable security definer set search_path to ''
as $$
  select (select private.get_role()) = 'admin'
    or exists (
      select 1 from public.meal_plans mp
      where mp.id = p_plan_id
        and mp.trainer_id = (select private.my_trainer_id())
    )
    or exists (
      select 1 from public.athlete_meal_plans amp
      where amp.meal_plan_id = p_plan_id
        and amp.athlete_id = (select private.my_athlete_id())
    );
$$;

create or replace function private.trains_athlete(p_athlete_id uuid)
returns boolean language sql stable security definer set search_path to ''
as $$
  select exists (
    select 1 from public.athletes a
    where a.id = p_athlete_id
      and a.trainer_id = (select private.my_trainer_id())
  );
$$;

revoke all on function private.owns_meal_plan(uuid) from public, anon;
revoke all on function private.can_read_meal_plan(uuid) from public, anon;
revoke all on function private.trains_athlete(uuid) from public, anon;
grant execute on function private.owns_meal_plan(uuid) to authenticated;
grant execute on function private.can_read_meal_plan(uuid) to authenticated;
grant execute on function private.trains_athlete(uuid) to authenticated;

-- ---------- meal_plans ----------
drop policy if exists meal_plans_all on public.meal_plans;

create policy meal_plans_select on public.meal_plans
  for select to authenticated
  using ((select private.can_read_meal_plan(id)));

create policy meal_plans_insert on public.meal_plans
  for insert to authenticated
  with check (
    trainer_id = (select private.my_trainer_id())
    or (select private.get_role()) = 'admin'
  );

create policy meal_plans_update on public.meal_plans
  for update to authenticated
  using (
    trainer_id = (select private.my_trainer_id())
    or (select private.get_role()) = 'admin'
  )
  with check (
    trainer_id = (select private.my_trainer_id())
    or (select private.get_role()) = 'admin'
  );

create policy meal_plans_delete on public.meal_plans
  for delete to authenticated
  using (
    trainer_id = (select private.my_trainer_id())
    or (select private.get_role()) = 'admin'
  );

-- ---------- meal_plan_items ----------
drop policy if exists meal_plan_items_all on public.meal_plan_items;

create policy meal_plan_items_select on public.meal_plan_items
  for select to authenticated
  using ((select private.can_read_meal_plan(meal_plan_id)));

create policy meal_plan_items_insert on public.meal_plan_items
  for insert to authenticated
  with check (
    (select private.owns_meal_plan(meal_plan_id))
    or (select private.get_role()) = 'admin'
  );

create policy meal_plan_items_update on public.meal_plan_items
  for update to authenticated
  using (
    (select private.owns_meal_plan(meal_plan_id))
    or (select private.get_role()) = 'admin'
  )
  with check (
    (select private.owns_meal_plan(meal_plan_id))
    or (select private.get_role()) = 'admin'
  );

create policy meal_plan_items_delete on public.meal_plan_items
  for delete to authenticated
  using (
    (select private.owns_meal_plan(meal_plan_id))
    or (select private.get_role()) = 'admin'
  );

-- ---------- athlete_meal_plans ----------
drop policy if exists athlete_meal_plans_all on public.athlete_meal_plans;

create policy athlete_meal_plans_select on public.athlete_meal_plans
  for select to authenticated
  using (
    athlete_id = (select private.my_athlete_id())
    or (select private.trains_athlete(athlete_id))
    or (select private.get_role()) = 'admin'
  );

create policy athlete_meal_plans_insert on public.athlete_meal_plans
  for insert to authenticated
  with check (
    ((select private.trains_athlete(athlete_id))
      and (select private.owns_meal_plan(meal_plan_id)))
    or (select private.get_role()) = 'admin'
  );

create policy athlete_meal_plans_update on public.athlete_meal_plans
  for update to authenticated
  using (
    (select private.trains_athlete(athlete_id))
    or (select private.get_role()) = 'admin'
  )
  with check (
    ((select private.trains_athlete(athlete_id))
      and (select private.owns_meal_plan(meal_plan_id)))
    or (select private.get_role()) = 'admin'
  );

create policy athlete_meal_plans_delete on public.athlete_meal_plans
  for delete to authenticated
  using (
    (select private.trains_athlete(athlete_id))
    or (select private.get_role()) = 'admin'
  );
