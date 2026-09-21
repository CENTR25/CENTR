-- Redesign RLS on public.exercises for a shared global catalog + per-trainer
-- private exercises.
--   * global rows: created_by_trainer IS NULL (source='seed'), readable by everyone
--   * private rows: created_by_trainer = a trainer's id, readable only by that
--     trainer and that trainer's students; writable only by the owner
-- Global seeding is done with the service role (bypasses RLS).

alter table public.exercises enable row level security;

create index if not exists idx_exercises_created_by_trainer
  on public.exercises (created_by_trainer);

drop policy if exists "exercises_select" on public.exercises;
drop policy if exists "Permitir crear ejercicios a autenticados" on public.exercises;
drop policy if exists "Permitir editar propios ejercicios" on public.exercises;
drop policy if exists "Permitir eliminar propios ejercicios" on public.exercises;

-- SELECT: global rows to all; private rows to the owning trainer or that
-- trainer's students (so students can see private exercises used in their routines).
create policy "exercises_select_v2"
on public.exercises for select
to authenticated
using (
  created_by_trainer is null
  or (select auth.uid()) in (
    select t.user_id from public.trainers t
    where t.id = exercises.created_by_trainer
  )
  or exists (
    select 1 from public.athletes a
    where a.user_id = (select auth.uid())
      and a.trainer_id = exercises.created_by_trainer
  )
);

-- INSERT: only rows the caller owns. Blocks client-created global (NULL owner)
-- or foreign-owned rows. Seeding uses the service role and bypasses this.
create policy "exercises_insert_v2"
on public.exercises for insert
to authenticated
with check (
  created_by_trainer is not null
  and (select auth.uid()) in (
    select t.user_id from public.trainers t
    where t.id = exercises.created_by_trainer
  )
);

-- UPDATE: owner-only. WITH CHECK stops re-pointing created_by_trainer.
create policy "exercises_update_v2"
on public.exercises for update
to authenticated
using (
  (select auth.uid()) in (
    select t.user_id from public.trainers t
    where t.id = exercises.created_by_trainer
  )
)
with check (
  (select auth.uid()) in (
    select t.user_id from public.trainers t
    where t.id = exercises.created_by_trainer
  )
);

-- DELETE: owner-only.
create policy "exercises_delete_v2"
on public.exercises for delete
to authenticated
using (
  (select auth.uid()) in (
    select t.user_id from public.trainers t
    where t.id = exercises.created_by_trainer
  )
);
