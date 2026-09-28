-- Migration: add_check_in_assigned_date
-- Adds assigned_date column to check_ins for trainer-controlled scheduling.
-- Also adds a trainer UPDATE policy so trainers can set/edit the assigned_date
-- and other fields on their athletes' check-ins.

ALTER TABLE public.check_ins
  ADD COLUMN assigned_date date NULL;

COMMENT ON COLUMN public.check_ins.assigned_date IS
  'Optional date assigned by the trainer for this check-in (NULL = unscheduled / athlete-initiated).';

CREATE POLICY check_ins_trainer_update
  ON public.check_ins
  FOR UPDATE
  TO authenticated
  USING (
    user_id IN (
      SELECT a.user_id FROM public.athletes a
      WHERE a.trainer_id = (SELECT private.my_trainer_id())
    )
    OR (SELECT private.get_role()) = 'admin'
  )
  WITH CHECK (
    user_id IN (
      SELECT a.user_id FROM public.athletes a
      WHERE a.trainer_id = (SELECT private.my_trainer_id())
    )
    OR (SELECT private.get_role()) = 'admin'
  );
