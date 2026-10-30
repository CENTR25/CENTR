-- Migration: add audience targeting to news_articles
-- Applied: 2026-10-30
-- "Visible para" selector in the admin Nueva noticia screen:
--   'all'      → everyone (default; back-compat for existing rows)
--   'students' → only students
--   'trainers' → only trainers
-- Trainers have no news feed today, so in practice this hides 'trainers'-only
-- articles from the student feed (studentNewsProvider filters to all+students).

ALTER TABLE public.news_articles
  ADD COLUMN IF NOT EXISTS audience text NOT NULL DEFAULT 'all'
    CHECK (audience IN ('all', 'trainers', 'students'));

CREATE INDEX IF NOT EXISTS news_articles_audience_idx
  ON public.news_articles(audience);
