-- trainer_exercise_media: per-trainer media overlay on any exercise (seed or custom).
-- Allows a trainer to attach their own video/photos to a shared/global exercise
-- without duplicating the exercise row. Students of that trainer see the overlay
-- media automatically. Applied 2026-10-30 via Supabase MCP.

CREATE TABLE IF NOT EXISTS public.trainer_exercise_media (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trainer_id  uuid NOT NULL REFERENCES public.trainers(id) ON DELETE CASCADE,
  exercise_id uuid NOT NULL REFERENCES public.exercises(id) ON DELETE CASCADE,
  video_url   text,
  image_urls  text[] NOT NULL DEFAULT '{}',
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT trainer_exercise_media_unique UNIQUE (trainer_id, exercise_id)
);

ALTER TABLE public.trainer_exercise_media ENABLE ROW LEVEL SECURITY;

-- Trainers can read their own overlay rows
CREATE POLICY "tem_trainer_select"
  ON public.trainer_exercise_media FOR SELECT
  USING (
    (SELECT auth.uid()) IN (
      SELECT t.user_id FROM public.trainers t WHERE t.id = trainer_id
    )
  );

-- Athletes can read overlay rows belonging to their own trainer
CREATE POLICY "tem_athlete_select"
  ON public.trainer_exercise_media FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.athletes a
      WHERE a.user_id = (SELECT auth.uid())
        AND a.trainer_id = trainer_exercise_media.trainer_id
    )
  );

-- Trainers can insert their own overlay rows
CREATE POLICY "tem_trainer_insert"
  ON public.trainer_exercise_media FOR INSERT
  WITH CHECK (
    (SELECT auth.uid()) IN (
      SELECT t.user_id FROM public.trainers t WHERE t.id = trainer_id
    )
  );

-- Trainers can update their own overlay rows
CREATE POLICY "tem_trainer_update"
  ON public.trainer_exercise_media FOR UPDATE
  USING (
    (SELECT auth.uid()) IN (
      SELECT t.user_id FROM public.trainers t WHERE t.id = trainer_id
    )
  )
  WITH CHECK (
    (SELECT auth.uid()) IN (
      SELECT t.user_id FROM public.trainers t WHERE t.id = trainer_id
    )
  );

-- Trainers can delete their own overlay rows
CREATE POLICY "tem_trainer_delete"
  ON public.trainer_exercise_media FOR DELETE
  USING (
    (SELECT auth.uid()) IN (
      SELECT t.user_id FROM public.trainers t WHERE t.id = trainer_id
    )
  );

CREATE INDEX IF NOT EXISTS idx_trainer_exercise_media_trainer_exercise
  ON public.trainer_exercise_media (trainer_id, exercise_id);
