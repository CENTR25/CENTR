-- Let a trainer write to their own athletes' workout_sessions:
--   * UPDATE  -> override/edit weights & reps recorded by the athlete
--   * INSERT  -> log an in-person session the athlete didn't record
-- Predicate mirrors workout_sessions_trainer_read (private.my_trainer_id()).
-- Athlete's own insert/select policies are left untouched.

create policy workout_sessions_trainer_update on workout_sessions
  for update
  using (
    athlete_id in (
      select a.id from athletes a
      where a.trainer_id = (select private.my_trainer_id())
    )
    or (select private.get_role()) = 'admin'
  )
  with check (
    athlete_id in (
      select a.id from athletes a
      where a.trainer_id = (select private.my_trainer_id())
    )
    or (select private.get_role()) = 'admin'
  );

create policy workout_sessions_trainer_insert on workout_sessions
  for insert
  with check (
    athlete_id in (
      select a.id from athletes a
      where a.trainer_id = (select private.my_trainer_id())
    )
    or (select private.get_role()) = 'admin'
  );
