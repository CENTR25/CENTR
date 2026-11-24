-- Server-side "workout completed" notification for the trainer's Novedades feed.
--
-- Root cause of "Novedades not updating": the notification was inserted by the
-- student's client in a fire-and-forget chain AFTER the workout_sessions insert
-- (insert -> streak select -> streak upsert -> athletes select -> trainers
-- select -> notifications insert). When the student locks the phone / closes the
-- tab right after finishing, the chain dies midway, so the session is saved but
-- the trainer never gets a notification. A trigger makes it atomic with the insert.

create or replace function public.notify_trainer_workout_completed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_trainer_user uuid;
  v_name text;
  v_user uuid;
  v_minutes int;
begin
  if new.is_completed is not true then
    return new;
  end if;

  select t.user_id, coalesce(a.name, 'Alumno'), coalesce(a.user_id, a.id)
    into v_trainer_user, v_name, v_user
  from public.athletes a
  join public.trainers t on t.id = a.trainer_id
  where a.id = new.athlete_id;

  if v_trainer_user is null then
    return new;
  end if;

  v_minutes := round(coalesce(new.duration_seconds, 0) / 60.0);

  insert into public.notifications (user_id, type, title, message, data, is_read)
  values (
    v_trainer_user,
    'workoutCompleted',
    '¡Entrenamiento completado!',
    v_name || ' completó su entrenamiento' ||
      case when v_minutes > 0 then ' en ' || v_minutes || ' min' else '' end,
    jsonb_build_object('student_id', v_user, 'athlete_id', new.athlete_id),
    false
  );
  return new;
exception when others then
  -- Never block the workout save because of a notification problem.
  return new;
end;
$$;

revoke all on function public.notify_trainer_workout_completed() from public, anon, authenticated;

drop trigger if exists workout_sessions_notify_trainer on public.workout_sessions;
create trigger workout_sessions_notify_trainer
  after insert on public.workout_sessions
  for each row execute function public.notify_trainer_workout_completed();

-- One-off backfill: completed sessions since the last notification that worked
-- (2026-11-18 23:02 UTC) that never produced a trainer notification.
-- notifications_server_created_at forces created_at = now() on insert, so the
-- original timestamp is restored with an UPDATE afterwards.
do $$
declare
  r record;
  v_id uuid;
begin
  for r in
    select ws.created_at as ws_created, ws.athlete_id,
           t.user_id as trainer_user, coalesce(a.name, 'Alumno') as nm,
           coalesce(a.user_id, a.id) as uid,
           round(coalesce(ws.duration_seconds, 0) / 60.0)::int as mins
    from public.workout_sessions ws
    join public.athletes a on a.id = ws.athlete_id
    join public.trainers t on t.id = a.trainer_id
    where ws.is_completed is true
      and ws.created_at > timestamptz '2026-11-18 23:02:00+00'
      and not exists (
        select 1 from public.notifications n
        where n.user_id = t.user_id and n.type = 'workoutCompleted'
          and n.data->>'athlete_id' = ws.athlete_id::text
          and n.created_at between ws.created_at - interval '1 minute'
                               and ws.created_at + interval '10 minutes'
      )
  loop
    insert into public.notifications (user_id, type, title, message, data, is_read)
    values (r.trainer_user, 'workoutCompleted', '¡Entrenamiento completado!',
            r.nm || ' completó su entrenamiento' ||
              case when r.mins > 0 then ' en ' || r.mins || ' min' else '' end,
            jsonb_build_object('student_id', r.uid, 'athlete_id', r.athlete_id), false)
    returning id into v_id;
    update public.notifications set created_at = r.ws_created where id = v_id;
  end loop;
end $$;
