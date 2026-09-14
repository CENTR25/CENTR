-- Allow trainers to INSERT/UPDATE body_progress rows for their own students.
-- Trainers already have SELECT via body_progress_staff; this adds write access.
CREATE POLICY body_progress_trainer_write
  ON public.body_progress
  FOR ALL
  TO authenticated
  USING (
    athlete_id IN (
      SELECT id FROM public.athletes
       WHERE trainer_id = (SELECT private.my_trainer_id())
    )
  )
  WITH CHECK (
    athlete_id IN (
      SELECT id FROM public.athletes
       WHERE trainer_id = (SELECT private.my_trainer_id())
    )
  );
