-- Allow admin to fully edit AND delete global exercises, and upload admin media.
-- Applied to prod 2026-09-25 (migration: admin_exercise_edit_delete_and_media).
--
-- Context:
--   * add_admin_exercise_rls.sql installed a BEFORE UPDATE trigger that blocked
--     admins from changing any field other than is_hidden on global exercises.
--   * The exercise-media storage bucket only allowed trainers (or the check_ins
--     folder) to INSERT, so admin brand-logo uploads silently 403'd.

-- 1) Relax the trigger: admins edit global rows freely. Trainer-vs-trainer
--    protection is enforced by the exercises UPDATE RLS policy, not this trigger,
--    so returning NEW unconditionally is safe.
CREATE OR REPLACE FUNCTION public.exercises_admin_global_addonly()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  RETURN NEW;
END;
$$;

-- 2) DELETE: admins may delete global exercises (created_by_trainer IS NULL)
DROP POLICY IF EXISTS exercises_admin_delete ON public.exercises;
CREATE POLICY exercises_admin_delete ON public.exercises
  FOR DELETE
  TO authenticated
  USING (
    created_by_trainer IS NULL
    AND (( SELECT private.get_role() ) = 'admin')
  );

-- 3) Storage: allow admin to upload/update exercise-media (brand logos, etc.).
--    Bucket already exists and is public; only INSERT/UPDATE policies were missing.
DROP POLICY IF EXISTS "admin upload exercise-media" ON storage.objects;
CREATE POLICY "admin upload exercise-media"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'exercise-media'
    AND (( SELECT private.get_role() ) = 'admin')
  );

DROP POLICY IF EXISTS "admin update exercise-media" ON storage.objects;
CREATE POLICY "admin update exercise-media"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'exercise-media'
    AND (( SELECT private.get_role() ) = 'admin')
  );
