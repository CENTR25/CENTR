-- Chat attachments: photos and voice notes in the student↔trainer chat.
--
-- Files live in a PRIVATE bucket (chat-media) — chat photos can be body /
-- progress pictures, so they must not be world-readable like exercise-media.
-- Object path: <athlete_id>/<random>.<ext>. Only the two conversation
-- participants (the athlete and their trainer) can upload or read; the app
-- displays files through short-lived signed URLs.

-- 1. messages columns ---------------------------------------------------------
alter table public.messages
  add column if not exists attachment_type text,
  add column if not exists attachment_path text,
  add column if not exists attachment_duration_ms integer;

alter table public.messages
  drop constraint if exists messages_attachment_type_check,
  add constraint messages_attachment_type_check
    check (attachment_type is null or attachment_type in ('image', 'audio'));

-- type and path go together, and the file must belong to THIS conversation's
-- folder (a message can't point at another conversation's media).
alter table public.messages
  drop constraint if exists messages_attachment_path_check,
  add constraint messages_attachment_path_check
    check (
      (attachment_type is null and attachment_path is null)
      or (attachment_type is not null
          and attachment_path like athlete_id::text || '/%'
          and attachment_path not like '%..%')
    );

-- a message is text, an attachment, or both — never empty.
alter table public.messages
  drop constraint if exists messages_not_empty_check,
  add constraint messages_not_empty_check
    check (btrim(body) <> '' or attachment_path is not null);

-- 2. private bucket -------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-media', 'chat-media', false, 10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic',
        'audio/mp4', 'audio/x-m4a', 'audio/aac', 'audio/webm', 'audio/ogg',
        'audio/mpeg']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- 3. storage policies: conversation participants only --------------------------
drop policy if exists "chat media participant read" on storage.objects;
create policy "chat media participant read"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'chat-media'
    and (
      exists (select 1 from public.athletes a
              where a.id::text = (storage.foldername(objects.name))[1]
                and a.user_id = (select auth.uid()))
      or exists (select 1 from public.athletes a
                 join public.trainers t on t.id = a.trainer_id
                 where a.id::text = (storage.foldername(objects.name))[1]
                   and t.user_id = (select auth.uid()))
    )
  );

drop policy if exists "chat media participant upload" on storage.objects;
create policy "chat media participant upload"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'chat-media'
    and (
      exists (select 1 from public.athletes a
              where a.id::text = (storage.foldername(objects.name))[1]
                and a.user_id = (select auth.uid()))
      or exists (select 1 from public.athletes a
                 join public.trainers t on t.id = a.trainer_id
                 where a.id::text = (storage.foldername(objects.name))[1]
                   and t.user_id = (select auth.uid()))
    )
  );
