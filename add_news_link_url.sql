-- Migration: optional external link on news_articles
-- Applied: 2026-11-15
-- Admin "Nueva noticia" gets a "Link (opcional)" field; tapping the news card
-- on the student home (dashboard) opens it externally, e.g. a brand
-- partnership post → the brand's Instagram. Other news surfaces (Novedades
-- list/detail, trainer Novedades) don't open the link yet.
-- Nullable: articles without a link keep their current behaviour.
-- CHECK restricts to http(s) so no javascript:/data: URLs can be stored.
-- Existing row-level RLS (news_articles_insert/update) already covers it.

ALTER TABLE public.news_articles
  ADD COLUMN IF NOT EXISTS link_url text
    CHECK (link_url IS NULL OR link_url ~* '^https?://');
