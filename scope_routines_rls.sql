-- Scope routine RLS (replaces USING (true) on routines, routine_exercises,
-- routine_day_titles, athlete_routines, which let any authenticated user —
-- students included — read/edit/delete every trainer's routines).
--
-- Access model:
--   routines / routine_exercises / routine_day_titles
--     read : owning trainer, admin, a student assigned to it or with a logged
--            session on it (history), and the trainer of such a student
--     write: owning trainer, admin
--   athlete_routines
--     read : the student themself, the student's trainer, admin
--     write: the student's trainer (and only for routines that trainer owns), admin
--
-- Reuses private.trains_athlete() from scope_meal_plans_rls.sql.

create or replace function private.owns_routine(p_routine_id uuid)
returns boolean language sql stable security definer set search_path to ''
as $$
  select exists (
    select 1 from public.routines r
    where r.id = p_routine_id
      and r.trainer_id = (select private.my_trainer_id())
  );
$$;

create or replace function private.can_read_routine(p_routine_id uuid)
returns boolean language sql stable security definer set search_path to ''
as $$
  with me as (
    select (select private.my_trainer_id()) as tid,
           (select private.my_athlete_id()) as aid
  )
  select (select private.get_role()) = 'admin'
    or exists (
      select 1 from public.routines r, me
      where r.id = p_routine_id and r.trainer_id = me.tid
    )
    or exists (
      select 1 from public.athlete_routines ar
      join public.athletes a on a.id = ar.athlete_id, me
      where ar.routine_id = p_routine_id
        and (ar.athlete_id = me.aid or a.trainer_id = me.tid)
    )
    or exists (
      select 1 from public.workout_sessions ws
      join public.athletes a on a.id = ws.athlete_id, me
      where ws.routine_id = p_routine_id
        and (ws.athlete_id = me.aid or a.trainer_id = me.tid)
    );
$$;

revoke all on function private.owns_routine(uuid) from public, anon;
revoke all on function private.can_read_routine(uuid) from public, anon;
grant execute on function private.owns_routine(uuid) to authenticated;
grant execute on function private.can_read_routine(uuid) to authenticated;

-- ---------- routines ----------
drop policy if exists routines_select on public.routines;
drop policy if exists routines_insert on public.routines;
drop policy if exists routines_update on public.routines;
drop policy if exists routines_delete on public.routines;

create policy routines_select on public.routines for select to authenticated
  using ((select private.can_read_routine(id)));
create policy routines_insert on public.routines for insert to authenticated
  with check (trainer_id = (select private.my_trainer_id()) or (select private.get_role()) = 'admin');
create policy routines_update on public.routines for update to authenticated
  using (trainer_id = (select private.my_trainer_id()) or (select private.get_role()) = 'admin')
  with check (trainer_id = (select private.my_trainer_id()) or (select private.get_role()) = 'admin');
create policy routines_delete on public.routines for delete to authenticated
  using (trainer_id = (select private.my_trainer_id()) or (select private.get_role()) = 'admin');

-- ---------- routine_exercises ----------
drop policy if exists routine_exercises_all on public.routine_exercises;

create policy routine_exercises_select on public.routine_exercises for select to authenticated
  using ((select private.can_read_routine(routine_id)));
create policy routine_exercises_insert on public.routine_exercises for insert to authenticated
  with check ((select private.owns_routine(routine_id)) or (select private.get_role()) = 'admin');
create policy routine_exercises_update on public.routine_exercises for update to authenticated
  using ((select private.owns_routine(routine_id)) or (select private.get_role()) = 'admin')
  with check ((select private.owns_routine(routine_id)) or (select private.get_role()) = 'admin');
create policy routine_exercises_delete on public.routine_exercises for delete to authenticated
  using ((select private.owns_routine(routine_id)) or (select private.get_role()) = 'admin');

-- ---------- routine_day_titles ----------
drop policy if exists routine_day_titles_all on public.routine_day_titles;

create policy routine_day_titles_select on public.routine_day_titles for select to authenticated
  using ((select private.can_read_routine(routine_id)));
create policy routine_day_titles_insert on public.routine_day_titles for insert to authenticated
  with check ((select private.owns_routine(routine_id)) or (select private.get_role()) = 'admin');
create policy routine_day_titles_update on public.routine_day_titles for update to authenticated
  using ((select private.owns_routine(routine_id)) or (select private.get_role()) = 'admin')
  with check ((select private.owns_routine(routine_id)) or (select private.get_role()) = 'admin');
create policy routine_day_titles_delete on public.routine_day_titles for delete to authenticated
  using ((select private.owns_routine(routine_id)) or (select private.get_role()) = 'admin');

-- ---------- athlete_routines ----------
drop policy if exists athlete_routines_all on public.athlete_routines;

create policy athlete_routines_select on public.athlete_routines for select to authenticated
  using (athlete_id = (select private.my_athlete_id()) or (select private.trains_athlete(athlete_id)) or (select private.get_role()) = 'admin');
create policy athlete_routines_insert on public.athlete_routines for insert to authenticated
  with check (((select private.trains_athlete(athlete_id)) and (select private.owns_routine(routine_id))) or (select private.get_role()) = 'admin');
create policy athlete_routines_update on public.athlete_routines for update to authenticated
  using ((select private.trains_athlete(athlete_id)) or (select private.get_role()) = 'admin')
  with check (((select private.trains_athlete(athlete_id)) and (select private.owns_routine(routine_id))) or (select private.get_role()) = 'admin');
create policy athlete_routines_delete on public.athlete_routines for delete to authenticated
  using ((select private.trains_athlete(athlete_id)) or (select private.get_role()) = 'admin');
