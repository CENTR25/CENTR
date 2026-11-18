-- Students could not save "Editar perfil" with a new photo: uploads to
-- exercise-media/avatars/ returned 400 because only trainers/admins had an
-- INSERT policy on that bucket. Allow any authenticated user to write ONLY
-- their own avatar files (path: avatars/<auth.uid()>_<timestamp>.<ext>).
-- uploadAvatarBytes uses upsert:true, so UPDATE is granted on the same scope.

drop policy if exists "Users upload own avatar" on storage.objects;
create policy "Users upload own avatar"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'exercise-media'
    and name like 'avatars/' || (select auth.uid())::text || '\_%'
  );

drop policy if exists "Users update own avatar" on storage.objects;
create policy "Users update own avatar"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'exercise-media'
    and name like 'avatars/' || (select auth.uid())::text || '\_%'
  )
  with check (
    bucket_id = 'exercise-media'
    and name like 'avatars/' || (select auth.uid())::text || '\_%'
  );
