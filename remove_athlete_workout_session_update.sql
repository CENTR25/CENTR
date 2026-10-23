-- Anti-cheat: students must not be able to modify a logged workout session.
-- Corrections go through the trainer. Athletes keep INSERT (live logging) and
-- SELECT; trainers/admins retain UPDATE via workout_sessions_trainer_update.
-- There is no DELETE policy, so athlete deletes are already denied by RLS.
DROP POLICY IF EXISTS "workout_sessions_athlete_update" ON public.workout_sessions;
