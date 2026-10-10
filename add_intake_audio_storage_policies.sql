-- Intake voice notes: allow authenticated users to upload/update their own
-- audio under exercise-media/intake-audio/<their-uid>/...
-- SELECT is already covered by "Authenticated users can read exercise media";
-- the exercise-media bucket is public, so playback uses the public URL.

create policy "Users upload own intake audio"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'exercise-media'
    and (storage.foldername(name))[1] = 'intake-audio'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

create policy "Users update own intake audio"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'exercise-media'
    and (storage.foldername(name))[1] = 'intake-audio'
    and (storage.foldername(name))[2] = auth.uid()::text
  );
