-- Migration: add trainer_id scope to news_articles
-- Applied: 2026-10-09
-- Convention: trainer_id IS NULL  = global/admin news (all students see it)
--             trainer_id NOT NULL = that trainer's news (only their athletes see it)

-- 1. Add column
ALTER TABLE public.news_articles
  ADD COLUMN IF NOT EXISTS trainer_id uuid REFERENCES public.trainers(id) ON DELETE CASCADE;

-- 2. Index for student feed query  (trainer_id IS NULL OR trainer_id = X)
CREATE INDEX IF NOT EXISTS news_articles_trainer_id_idx ON public.news_articles(trainer_id);

-- 3. Drop old admin-only policies
DROP POLICY IF EXISTS news_articles_select        ON public.news_articles;
DROP POLICY IF EXISTS news_articles_admin_insert  ON public.news_articles;
DROP POLICY IF EXISTS news_articles_admin_update  ON public.news_articles;
DROP POLICY IF EXISTS news_articles_admin_delete  ON public.news_articles;
-- (also drop new names in case of re-run)
DROP POLICY IF EXISTS news_articles_insert        ON public.news_articles;
DROP POLICY IF EXISTS news_articles_update        ON public.news_articles;
DROP POLICY IF EXISTS news_articles_delete        ON public.news_articles;

-- 4. SELECT
--    • Published rows  → any authenticated user
--    • Unpublished rows → admin (all) OR the owning trainer (their own rows only)
CREATE POLICY news_articles_select
  ON public.news_articles
  FOR SELECT
  TO authenticated
  USING (
    is_published = true
    OR (SELECT private.get_role()) = 'admin'
    OR (
      trainer_id IS NOT NULL
      AND trainer_id = (SELECT private.my_trainer_id())
    )
  );

-- 5. INSERT
--    • Admin  → any row (trainer_id may be null for global news)
--    • Trainer → only rows where trainer_id = their own trainers.id
CREATE POLICY news_articles_insert
  ON public.news_articles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT private.get_role()) = 'admin'
    OR (
      (SELECT private.get_role()) = 'trainer'
      AND trainer_id IS NOT NULL
      AND trainer_id = (SELECT private.my_trainer_id())
    )
  );

-- 6. UPDATE
--    • Admin  → any row
--    • Trainer → their own rows only
CREATE POLICY news_articles_update
  ON public.news_articles
  FOR UPDATE
  TO authenticated
  USING (
    (SELECT private.get_role()) = 'admin'
    OR (
      (SELECT private.get_role()) = 'trainer'
      AND trainer_id IS NOT NULL
      AND trainer_id = (SELECT private.my_trainer_id())
    )
  )
  WITH CHECK (
    (SELECT private.get_role()) = 'admin'
    OR (
      (SELECT private.get_role()) = 'trainer'
      AND trainer_id IS NOT NULL
      AND trainer_id = (SELECT private.my_trainer_id())
    )
  );

-- 7. DELETE
--    • Admin  → any row
--    • Trainer → their own rows only
CREATE POLICY news_articles_delete
  ON public.news_articles
  FOR DELETE
  TO authenticated
  USING (
    (SELECT private.get_role()) = 'admin'
    OR (
      (SELECT private.get_role()) = 'trainer'
      AND trainer_id IS NOT NULL
      AND trainer_id = (SELECT private.my_trainer_id())
    )
  );
