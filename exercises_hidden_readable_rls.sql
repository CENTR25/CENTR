-- 2026-11-17: is_hidden means "removed from the catalog list", not "unreadable".
-- delete_or_hide_exercises hides globals that routines / workout history still
-- reference; if RLS also hid them, routine embeds (routine_exercises -> exercises)
-- returned null for trainers/students (blank names, workout screen crash).
-- Catalog lists filter is_hidden client-side (TrainerService.getExercises).
drop policy if exists exercises_select_v2 on public.exercises;
create policy exercises_select_v2 on public.exercises
  for select to authenticated
  using (
    ((select private.get_role()) = 'admin')
    or (created_by_trainer is null)
    or ((select auth.uid()) in (
          select t.user_id from public.trainers t
          where t.id = exercises.created_by_trainer))
    or (exists (
          select 1 from public.athletes a
          where a.user_id = (select auth.uid())
            and a.trainer_id = exercises.created_by_trainer))
  );
