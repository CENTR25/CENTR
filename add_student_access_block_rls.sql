-- Database-level enforcement of the student access block.
-- APPLIED to prod 2026-11-25 (in chunks via the SQL editor). Depends on
-- add_student_access_block.sql.
--
-- RESTRICTIVE policies are AND-ed with every existing permissive policy, so a
-- blocked student gets zero rows / rejected writes on these tables. Trainers,
-- admins and the service role are unaffected (i_am_blocked() is false for them).
-- NOT restricted on purpose (needed to sign in / show the suspended screen):
-- profiles, athletes, trainers, notifications. student_payments is
-- trainer-only already. New student data tables must be added here by hand.

CREATE OR REPLACE FUNCTION private.is_blocked(
  p_manual  boolean,
  p_renewal timestamptz,
  p_auto    boolean,
  p_grace   integer
) RETURNS boolean
LANGUAGE sql STABLE
AS $$
  SELECT coalesce(p_manual, false)
      OR (coalesce(p_auto, false)
          AND p_renewal IS NOT NULL
          AND (p_renewal::date + coalesce(p_grace, 0)) < current_date);
$$;

CREATE OR REPLACE FUNCTION private.i_am_blocked()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT coalesce(bool_or(private.is_blocked(
           a.access_blocked, a.next_renewal_date,
           t.auto_block_enabled, t.auto_block_grace_days)), false)
  FROM public.athletes a
  JOIN public.trainers t ON t.id = a.trainer_id
  WHERE a.user_id = (SELECT auth.uid());
$$;
REVOKE ALL ON FUNCTION private.i_am_blocked() FROM public, anon;
GRANT EXECUTE ON FUNCTION private.i_am_blocked() TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_blocked(boolean, timestamptz, boolean, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.my_access_status()
RETURNS TABLE (blocked boolean, reason text, trainer_name text, auto boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT
    private.is_blocked(a.access_blocked, a.next_renewal_date,
                       t.auto_block_enabled, t.auto_block_grace_days),
    CASE WHEN a.access_blocked THEN a.block_reason
         ELSE 'Tu cuota venció y no se registró el pago.' END,
    t.name,
    (NOT a.access_blocked)
  FROM public.athletes a
  JOIN public.trainers t ON t.id = a.trainer_id
  WHERE a.user_id = (SELECT auth.uid());
$$;
REVOKE ALL ON FUNCTION public.my_access_status() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.my_access_status() TO authenticated;

DROP POLICY IF EXISTS blocked_student_denied ON public.achievements;
CREATE POLICY blocked_student_denied ON public.achievements
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.affiliated_brands;
CREATE POLICY blocked_student_denied ON public.affiliated_brands
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.articles;
CREATE POLICY blocked_student_denied ON public.articles
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.athlete_intake;
CREATE POLICY blocked_student_denied ON public.athlete_intake
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.athlete_meal_plans;
CREATE POLICY blocked_student_denied ON public.athlete_meal_plans
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.athlete_routines;
CREATE POLICY blocked_student_denied ON public.athlete_routines
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.athlete_supplements;
CREATE POLICY blocked_student_denied ON public.athlete_supplements
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.athlete_training_schedule;
CREATE POLICY blocked_student_denied ON public.athlete_training_schedule
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.body_progress;
CREATE POLICY blocked_student_denied ON public.body_progress
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.check_in_form_responses;
CREATE POLICY blocked_student_denied ON public.check_in_form_responses
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.check_in_forms;
CREATE POLICY blocked_student_denied ON public.check_in_forms
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.check_in_photos;
CREATE POLICY blocked_student_denied ON public.check_in_photos
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.check_ins;
CREATE POLICY blocked_student_denied ON public.check_ins
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.daily_steps;
CREATE POLICY blocked_student_denied ON public.daily_steps
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.default_meals;
CREATE POLICY blocked_student_denied ON public.default_meals
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.exercises;
CREATE POLICY blocked_student_denied ON public.exercises
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.foods;
CREATE POLICY blocked_student_denied ON public.foods
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.intake_form_schemas;
CREATE POLICY blocked_student_denied ON public.intake_form_schemas
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.leaderboard_entries;
CREATE POLICY blocked_student_denied ON public.leaderboard_entries
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.meal_completions;
CREATE POLICY blocked_student_denied ON public.meal_completions
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.meal_plan_items;
CREATE POLICY blocked_student_denied ON public.meal_plan_items
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.meal_plans;
CREATE POLICY blocked_student_denied ON public.meal_plans
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.messages;
CREATE POLICY blocked_student_denied ON public.messages
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.muscle_groups;
CREATE POLICY blocked_student_denied ON public.muscle_groups
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.news_articles;
CREATE POLICY blocked_student_denied ON public.news_articles
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.routine_day_titles;
CREATE POLICY blocked_student_denied ON public.routine_day_titles
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.routine_exercises;
CREATE POLICY blocked_student_denied ON public.routine_exercises
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.routines;
CREATE POLICY blocked_student_denied ON public.routines
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.streaks;
CREATE POLICY blocked_student_denied ON public.streaks
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.supplement_logs;
CREATE POLICY blocked_student_denied ON public.supplement_logs
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.trainer_tasks;
CREATE POLICY blocked_student_denied ON public.trainer_tasks
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.workout_logs;
CREATE POLICY blocked_student_denied ON public.workout_logs
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

DROP POLICY IF EXISTS blocked_student_denied ON public.workout_sessions;
CREATE POLICY blocked_student_denied ON public.workout_sessions
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));

-- Storage (check-in photos, chat media). Needs the storage owner role;
-- run from the Supabase SQL editor. Not applied yet if this line is still here.
DROP POLICY IF EXISTS blocked_student_denied ON storage.objects;
CREATE POLICY blocked_student_denied ON storage.objects
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT (SELECT private.i_am_blocked()))
  WITH CHECK (NOT (SELECT private.i_am_blocked()));
