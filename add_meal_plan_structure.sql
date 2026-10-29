-- Structured fields for the "Nuevo plan" creation flow (Figma).
-- objective: goal tag (Déficit / Ganar masa muscular / Rendimiento / Salud / Mantener).
-- days: how many days the plan spans (drives the Día pills; no more deriving from items).
-- meal_times: which meal slots the plan uses (Desayuno/Almuerzo/Merienda/Cena).
alter table public.meal_plans
  add column if not exists objective text,
  add column if not exists days integer,
  add column if not exists meal_times text[];
