-- Remove the old global (owner-NULL) exercises that are NOT referenced by any
-- routine, so the Spanish PRGS catalog replaces the old English seed set.
-- Referenced rows are kept so existing routines don't break.
-- Run this BEFORE seed_exercises_154.sql.

delete from public.exercises e
where e.created_by_trainer is null
  and not exists (
    select 1 from public.routine_exercises re where re.exercise_id = e.id
  );
