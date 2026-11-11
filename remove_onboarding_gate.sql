-- Migration: remove_onboarding_gate.sql
-- The height/weight/goal onboarding screen has been removed. Height and weight
-- are now captured in the intake questionnaire. The onboarding gate is no
-- longer used in routing.
--
-- 1. Set has_completed_onboarding = true for all students who already finished
--    the intake form (they are past that step).
-- 2. Change the column default to true so new students created after this
--    migration are never blocked by the old gate.

-- Backfill existing students who have completed intake
update public.profiles
set has_completed_onboarding = true
where has_completed_intake = true;

-- New students no longer go through the onboarding screen
alter table public.profiles
  alter column has_completed_onboarding set default true;
