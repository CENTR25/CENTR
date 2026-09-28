-- Migration: add_affiliated_brands_benefit
-- Adds benefit_description column to affiliated_brands for richer benefit copy
-- shown to athletes in the Beneficios tab.
-- Note: display_order already exists — NOT re-added here.

ALTER TABLE public.affiliated_brands
  ADD COLUMN benefit_description text NULL;

COMMENT ON COLUMN public.affiliated_brands.benefit_description IS
  'Free-text description of the benefit or discount offered by this affiliated brand (shown to athletes in Beneficios tab).';
