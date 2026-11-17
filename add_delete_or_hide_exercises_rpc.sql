-- Safe exercise deletion (bulk + single).
--
-- routine_exercises.exercise_id and trainer_exercise_media.exercise_id are
-- ON DELETE CASCADE, so a plain DELETE on an exercise silently strips it out of
-- every routine that uses it. This RPC deletes only exercises NOT referenced by
-- any routine or workout history; referenced ones are hidden (is_hidden = true).
--
-- SECURITY DEFINER so the "in use" check sees ALL routine_exercises (a
-- trainer's RLS view only covers their own routines). Ownership is enforced
-- inside the function on every write:
--   * admin   -> global exercises only (created_by_trainer IS NULL)
--   * trainer -> their own exercises only
-- Ids the caller may not touch are counted as "skipped".
--
-- Idempotent: CREATE OR REPLACE + re-grant.

create or replace function public.delete_or_hide_exercises(p_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_is_admin boolean := (select private.get_role()) = 'admin';
  v_tid uuid := (select private.my_trainer_id());
  v_allowed uuid[];
  v_in_use uuid[];
  v_deleted int := 0;
  v_hidden int := 0;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if p_ids is null or cardinality(p_ids) = 0 then
    return jsonb_build_object('deleted', 0, 'hidden', 0, 'skipped', 0);
  end if;
  if cardinality(p_ids) > 5000 then
    raise exception 'too many ids' using errcode = '22023';
  end if;

  -- Rows the caller owns (lock them so a concurrent routine insert waits).
  select coalesce(array_agg(e.id), '{}')
    into v_allowed
    from (
      select e.id
        from public.exercises e
       where e.id = any(p_ids)
         and (
           (v_is_admin and e.created_by_trainer is null)
           or (v_tid is not null and e.created_by_trainer = v_tid)
         )
       for update
    ) e;

  -- "In use" = referenced by a routine OR by workout history
  -- (workout_sessions.set_logs is keyed by exercise id, no FK) — deleting the
  -- latter would orphan students' past sets.
  select coalesce(array_agg(distinct x.id), '{}')
    into v_in_use
    from (
      select re.exercise_id as id
        from public.routine_exercises re
       where re.exercise_id = any(v_allowed)
      union
      select a.id
        from unnest(v_allowed) as a(id)
       where exists (
         select 1 from public.workout_sessions ws
          where jsonb_typeof(ws.set_logs) = 'object'
            and ws.set_logs ? a.id::text
       )
    ) x;

  update public.exercises e
     set is_hidden = true
   where e.id = any(v_in_use)
     and (
       (v_is_admin and e.created_by_trainer is null)
       or (v_tid is not null and e.created_by_trainer = v_tid)
     );
  v_hidden := cardinality(v_in_use);

  with d as (
    delete from public.exercises e
     where e.id = any(v_allowed)
       and not (e.id = any(v_in_use))
       and not exists (
         select 1 from public.routine_exercises re where re.exercise_id = e.id
       )
       and (
         (v_is_admin and e.created_by_trainer is null)
         or (v_tid is not null and e.created_by_trainer = v_tid)
       )
    returning 1
  )
  select count(*) into v_deleted from d;

  return jsonb_build_object(
    'deleted', v_deleted,
    'hidden', v_hidden,
    'skipped', cardinality(p_ids) - cardinality(v_allowed)
  );
end;
$$;

revoke all on function public.delete_or_hide_exercises(uuid[]) from public, anon;
grant execute on function public.delete_or_hide_exercises(uuid[]) to authenticated;
