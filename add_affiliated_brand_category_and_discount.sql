-- Migration: add_affiliated_brand_category_and_discount
-- Adds `category` (enum-checked text) and `discount_label` (free-text) to affiliated_brands.
--
-- category: nullable text with a CHECK constraint on three allowed slugs that
--   match the Beneficios filter chips (ropa / nutricion / salud).  NULL = no
--   category; the "Todos" chip still shows the card.
--
-- discount_label: nullable free-text headline shown big-and-bold on the card
--   (e.g. "15% OFF", "2x1", "Envío gratis").  Free-text is preferred over a
--   numeric percentage because real-world benefits are not always a percentage.
--   benefit_description keeps its role as the muted description line.

ALTER TABLE public.affiliated_brands
  ADD COLUMN category text
    CHECK (category IN ('ropa', 'nutricion', 'salud'))
    NULL;

ALTER TABLE public.affiliated_brands
  ADD COLUMN discount_label text NULL;

COMMENT ON COLUMN public.affiliated_brands.category IS
  'Optional category slug: ropa | nutricion | salud.  NULL = uncategorised (always shown under "Todos").';

COMMENT ON COLUMN public.affiliated_brands.discount_label IS
  'Free-text discount headline shown on the student Beneficios card, e.g. "15% OFF", "2x1", "Envío gratis".';
