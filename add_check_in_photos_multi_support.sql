-- Migration: add_check_in_photos_multi_support
-- check_ins store 3 competing photo mechanisms; canonical is the check_in_photos child table.
-- Fixes two gaps:
--   1. Storage lacked an athlete UPDATE policy (upsert silently failed without INSERT+SELECT+UPDATE).
--   2. check_in_photos lacked a trainer SELECT policy (trainers couldn't see submitted photos).

-- Storage: allow authenticated athletes to UPDATE (replace/upsert) their own check-in photos.
CREATE POLICY "Users update own check_in photos"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'exercise-media'
    AND (storage.foldername(name))[1] = 'check_ins'
  );

-- RLS: allow trainers to SELECT check_in_photos belonging to their athletes.
-- Joins through check_ins (owner = user_id) → athletes (trainer_id).
CREATE POLICY check_in_photos_trainer_read
  ON public.check_in_photos
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.check_ins ci
      JOIN public.athletes a ON a.user_id = ci.user_id
      WHERE ci.id = check_in_photos.check_in_id
        AND a.trainer_id = (SELECT private.my_trainer_id())
    )
    OR (SELECT private.get_role()) = 'admin'
  );
