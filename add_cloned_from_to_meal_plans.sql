-- Records the template a personalized meal plan was cloned from.
-- Already applied to prod (column exists as nullable uuid, no FK);
-- this file documents it in the repo per convention.
alter table public.meal_plans
  add column if not exists cloned_from uuid;
