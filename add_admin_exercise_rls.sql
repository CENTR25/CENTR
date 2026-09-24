-- Admin management of the GLOBAL exercise library (add-only).
--
-- Global exercises are the rows with created_by_trainer IS NULL (source='seed'
-- or admin-created 'global'). This migration lets role='admin':
--   * INSERT new global exercises (visible to every trainer/athlete)
--   * hide/unhide a global exercise via the new is_hidden flag
-- It deliberately does NOT grant admins destructive edits to the existing
-- shared fields (name, media, instructions, ...): a BEFORE UPDATE trigger
-- rejects any admin change to a global row other than the is_hidden flag.
--
-- Trainer/athlete access is unchanged except that hidden globals are no longer
-- returned to them (the SELECT policy is rewritten to add that filter and to
-- let admins see everything, including hidden rows, for management).

-- 1) Hide flag ---------------------------------------------------------------
ALTER TABLE public.exercises
  ADD COLUMN IF NOT EXISTS is_hidden boolean NOT NULL DEFAULT false;

-- 2) SELECT: hide hidden globals from non-admins; admins see all -------------
DROP POLICY IF EXISTS exercises_select_v2 ON public.exercises;
CREATE POLICY exercises_select_v2 ON public.exercises
  FOR SELECT
  TO authenticated
  USING (
    -- admins see everything (needed to manage hidden rows)
    (( SELECT private.get_role() ) = 'admin')
    -- global (seed / admin) exercises, unless hidden
    OR ((created_by_trainer IS NULL) AND (is_hidden IS NOT TRUE))
    -- the trainer's own private exercises
    OR (( SELECT auth.uid() ) IN (
          SELECT t.user_id FROM trainers t WHERE t.id = exercises.created_by_trainer))
    -- an athlete sees their trainer's private exercises
    OR (EXISTS (
          SELECT 1 FROM athletes a
          WHERE a.user_id = ( SELECT auth.uid() )
            AND a.trainer_id = exercises.created_by_trainer))
  );

-- 3) INSERT: admins may create global exercises (created_by_trainer IS NULL) --
DROP POLICY IF EXISTS exercises_admin_insert ON public.exercises;
CREATE POLICY exercises_admin_insert ON public.exercises
  FOR INSERT
  TO authenticated
  WITH CHECK (
    created_by_trainer IS NULL
    AND (( SELECT private.get_role() ) = 'admin')
  );

-- 4) UPDATE: admins may update global rows (row-level); the trigger below
--    restricts them to only the is_hidden flag (add-only, no destructive edit)
DROP POLICY IF EXISTS exercises_admin_update ON public.exercises;
CREATE POLICY exercises_admin_update ON public.exercises
  FOR UPDATE
  TO authenticated
  USING (
    created_by_trainer IS NULL
    AND (( SELECT private.get_role() ) = 'admin')
  )
  WITH CHECK (
    created_by_trainer IS NULL
    AND (( SELECT private.get_role() ) = 'admin')
  );

-- 5) Trigger: an admin editing a global row may only toggle is_hidden ---------
CREATE OR REPLACE FUNCTION public.exercises_admin_global_addonly()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  -- Only guard admin updates to global rows; trainer edits to their own rows
  -- are governed by exercises_update_v2 and are unaffected.
  IF OLD.created_by_trainer IS NULL AND ( SELECT private.get_role() ) = 'admin' THEN
    IF ROW(
         NEW.id, NEW.name, NEW.muscle_group, NEW.created_by_trainer, NEW.video_url,
         NEW.instructions, NEW.equipment, NEW.is_public, NEW.created_at, NEW.image_urls,
         NEW.body_part, NEW.target, NEW.secondary_muscles, NEW.instructions_i18n,
         NEW.instruction_steps_i18n, NEW.media_id, NEW.gif_url, NEW.source, NEW.category
       ) IS DISTINCT FROM ROW(
         OLD.id, OLD.name, OLD.muscle_group, OLD.created_by_trainer, OLD.video_url,
         OLD.instructions, OLD.equipment, OLD.is_public, OLD.created_at, OLD.image_urls,
         OLD.body_part, OLD.target, OLD.secondary_muscles, OLD.instructions_i18n,
         OLD.instruction_steps_i18n, OLD.media_id, OLD.gif_url, OLD.source, OLD.category
       ) THEN
      RAISE EXCEPTION 'Admins may only hide/unhide global exercises, not edit their fields';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS exercises_admin_global_addonly ON public.exercises;
CREATE TRIGGER exercises_admin_global_addonly
  BEFORE UPDATE ON public.exercises
  FOR EACH ROW
  EXECUTE FUNCTION public.exercises_admin_global_addonly();
