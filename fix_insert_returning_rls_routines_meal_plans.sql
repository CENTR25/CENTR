-- Fix: trainers could not create routines / meal plans ("new row violates
-- row-level security policy", 42501).
--
-- Root cause: PostgREST inserts with RETURNING (client uses .insert().select()).
-- RETURNING re-checks the SELECT policy, which called private.can_read_routine(id)
-- / can_read_meal_plan(id): STABLE functions that query the table by id. A stable
-- function uses the calling statement's snapshot, so it cannot see the row being
-- inserted -> returns false -> insert rejected. (Introduced by scope_routines_rls.sql
-- and scope_meal_plans_rls.sql.)
--
-- Fix: add an inline owner/admin check on the row's own columns to the SELECT
-- policies. Scoping is unchanged (owner, admin, assigned student, history readers).

drop policy if exists routines_select on public.routines;
create policy routines_select on public.routines for select to authenticated
  using (
    trainer_id = (select private.my_trainer_id())
    or (select private.get_role()) = 'admin'
    or (select private.can_read_routine(id))
  );

drop policy if exists meal_plans_select on public.meal_plans;
create policy meal_plans_select on public.meal_plans for select to authenticated
  using (
    trainer_id = (select private.my_trainer_id())
    or (select private.get_role()) = 'admin'
    or (select private.can_read_meal_plan(id))
  );
