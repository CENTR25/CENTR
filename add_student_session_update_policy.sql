-- Let athletes correct their own workout sessions after finishing them
-- (typo fixes on recorded weights/reps). Today workout_sessions only has an
-- UPDATE policy for trainers/admins, so a student's update silently affects
-- 0 rows. This policy is additive and scoped to the athlete's own rows.
--
-- RLS cannot column-scope an UPDATE, so this allows the owning athlete to touch
-- any column on their own row; the app only ever writes set_logs / reps_logs /
-- sets_completed from the student edit path. The WITH CHECK keeps the row's
-- athlete_id pinned to the caller (can't reassign a session to someone else).

create policy workout_sessions_athlete_update on workout_sessions
  for update
  using (
    auth.uid() in (
      select user_id from athletes where id = workout_sessions.athlete_id
    )
  )
  with check (
    auth.uid() in (
      select user_id from athletes where id = workout_sessions.athlete_id
    )
  );
