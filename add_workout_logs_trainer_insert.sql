-- Migration: add_workout_logs_trainer_insert
-- Allows trainers to INSERT and UPDATE workout_logs for their own athletes.
-- workout_logs_own (ALL) gates on my_athlete_id() which returns NULL for trainers,
-- so trainers were silently blocked from logging in-person sessions.

CREATE POLICY workout_logs_trainer_insert
  ON public.workout_logs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    athlete_id IN (
      SELECT a.id FROM public.athletes a
      WHERE a.trainer_id = (SELECT private.my_trainer_id())
    )
    OR (SELECT private.get_role()) = 'admin'
  );

CREATE POLICY workout_logs_trainer_update
  ON public.workout_logs
  FOR UPDATE
  TO authenticated
  USING (
    athlete_id IN (
      SELECT a.id FROM public.athletes a
      WHERE a.trainer_id = (SELECT private.my_trainer_id())
    )
    OR (SELECT private.get_role()) = 'admin'
  )
  WITH CHECK (
    athlete_id IN (
      SELECT a.id FROM public.athletes a
      WHERE a.trainer_id = (SELECT private.my_trainer_id())
    )
    OR (SELECT private.get_role()) = 'admin'
  );
