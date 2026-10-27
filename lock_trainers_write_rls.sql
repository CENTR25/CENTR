-- Lock down writes on public.trainers.
--
-- Before: trainers_insert / trainers_update / trainers_delete all had
-- `true` as their USING/WITH CHECK, so ANY authenticated user could create,
-- edit, or delete ANY trainer row (data tampering / destruction — e.g. a
-- student overwriting a trainer's required_reading or deleting every trainer).
-- This is not role escalation (the app role lives in profiles.role and is
-- enforced by private.get_role()), but it is a serious integrity hole.
--
-- After: a trainer may edit only their own row; admins may write any row.
-- Trainer provisioning/removal runs through the admin-auth Edge Function with
-- the service_role key, which bypasses RLS entirely, so regular users never
-- need INSERT/DELETE. SELECT is intentionally left as-is (students read their
-- coach's public info).

drop policy if exists "trainers_update" on public.trainers;       -- qual: true
drop policy if exists "Trainers update own" on public.trainers;   -- redundant, superseded below
drop policy if exists "trainers_insert" on public.trainers;       -- with_check: true
drop policy if exists "trainers_delete" on public.trainers;       -- qual: true

-- UPDATE: own row, or admin.
create policy "trainers_update" on public.trainers
  for update to authenticated
  using (
    user_id = (select auth.uid())
    or (select private.get_role()) = 'admin'
  )
  with check (
    user_id = (select auth.uid())
    or (select private.get_role()) = 'admin'
  );

-- INSERT: admins only (service_role edge function bypasses RLS regardless).
create policy "trainers_insert" on public.trainers
  for insert to authenticated
  with check ((select private.get_role()) = 'admin');

-- DELETE: admins only.
create policy "trainers_delete" on public.trainers
  for delete to authenticated
  using ((select private.get_role()) = 'admin');
