-- Tighten chat (messages) write rules. Two holes in create_messages.sql:
--  1. INSERT only checked conversation membership, not sender_role — a student
--     could post a message labelled as coming from their trainer (and vice
--     versa).
--  2. UPDATE allowed any column on any message in the conversation — either
--     participant could rewrite the other's body / sender / attachment.
-- The app only ever inserts with its own role and only updates is_read on
-- messages it received (MessagingService.markRead), so neither change affects
-- normal use.

-- 1. sender_role must match who the caller is in this conversation; new
--    messages always start unread.
drop policy if exists "messages_insert_participant" on public.messages;
create policy "messages_insert_participant"
  on public.messages for insert
  to authenticated
  with check (
    is_read = false
    and (
      (sender_role = 'student'
        and exists (select 1 from public.athletes a
                    where a.id = messages.athlete_id
                      and a.user_id = (select auth.uid())))
      or (sender_role = 'trainer'
        and exists (select 1 from public.athletes a
                    join public.trainers t on t.id = a.trainer_id
                    where a.id = messages.athlete_id
                      and t.user_id = (select auth.uid())))
    )
  );

-- 2a. Only is_read is updatable (column-level privilege; a table-level UPDATE
--     grant would override a column revoke, so revoke it and grant the column).
revoke update on public.messages from anon, authenticated;
grant update (is_read) on public.messages to authenticated;

-- 2b. ...and only on messages the caller RECEIVED (sent by the other party).
drop policy if exists "messages_update_participant" on public.messages;
create policy "messages_update_participant"
  on public.messages for update
  to authenticated
  using (
    (sender_role = 'trainer'
      and exists (select 1 from public.athletes a
                  where a.id = messages.athlete_id
                    and a.user_id = (select auth.uid())))
    or (sender_role = 'student'
      and exists (select 1 from public.athletes a
                  join public.trainers t on t.id = a.trainer_id
                  where a.id = messages.athlete_id
                    and t.user_id = (select auth.uid())))
  )
  with check (
    (sender_role = 'trainer'
      and exists (select 1 from public.athletes a
                  where a.id = messages.athlete_id
                    and a.user_id = (select auth.uid())))
    or (sender_role = 'student'
      and exists (select 1 from public.athletes a
                  join public.trainers t on t.id = a.trainer_id
                  where a.id = messages.athlete_id
                    and t.user_id = (select auth.uid())))
  );
