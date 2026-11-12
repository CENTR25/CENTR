-- ADR-005: editable meal slots, day labels and plan note (additive).
ALTER TABLE public.meal_plans
  ADD COLUMN IF NOT EXISTS meal_slots jsonb,
  ADD COLUMN IF NOT EXISTS day_labels jsonb,
  ADD COLUMN IF NOT EXISTS note text;

ALTER TABLE public.meal_plans
  DROP CONSTRAINT IF EXISTS meal_plans_meal_slots_array_check,
  ADD CONSTRAINT meal_plans_meal_slots_array_check
    CHECK (meal_slots IS NULL OR jsonb_typeof(meal_slots) = 'array'),
  DROP CONSTRAINT IF EXISTS meal_plans_day_labels_array_check,
  ADD CONSTRAINT meal_plans_day_labels_array_check
    CHECK (day_labels IS NULL OR jsonb_typeof(day_labels) = 'array');

-- Closed 6-key set -> format check, so custom slot_<hex> keys are allowed.
ALTER TABLE public.meal_plan_items
  DROP CONSTRAINT IF EXISTS meal_plan_items_time_of_day_check,
  ADD CONSTRAINT meal_plan_items_time_of_day_check
    CHECK (time_of_day ~ '^[a-z0-9_]{1,40}$');
