-- create_messages.sql
-- 1:1 student↔trainer chat. One conversation per athlete (each athlete has a
-- single trainer). sender_role identifies who wrote each message; the recipient
-- is the other participant, so a single is_read flag covers both directions.

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  sender_role text not null check (sender_role in ('student','trainer')),
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists messages_athlete_created_idx
  on public.messages (athlete_id, created_at);

alter table public.messages enable row level security;

-- Membership test: the athlete (athletes.user_id) or their trainer
-- (trainers.user_id via athletes.trainer_id) may read/write the conversation.
drop policy if exists "messages_select_participant" on public.messages;
create policy "messages_select_participant"
  on public.messages for select
  to authenticated
  using (
    exists (select 1 from public.athletes a
            where a.id = messages.athlete_id and a.user_id = auth.uid())
    or exists (select 1 from public.athletes a
               join public.trainers t on t.id = a.trainer_id
               where a.id = messages.athlete_id and t.user_id = auth.uid())
  );

drop policy if exists "messages_insert_participant" on public.messages;
create policy "messages_insert_participant"
  on public.messages for insert
  to authenticated
  with check (
    exists (select 1 from public.athletes a
            where a.id = messages.athlete_id and a.user_id = auth.uid())
    or exists (select 1 from public.athletes a
               join public.trainers t on t.id = a.trainer_id
               where a.id = messages.athlete_id and t.user_id = auth.uid())
  );

drop policy if exists "messages_update_participant" on public.messages;
create policy "messages_update_participant"
  on public.messages for update
  to authenticated
  using (
    exists (select 1 from public.athletes a
            where a.id = messages.athlete_id and a.user_id = auth.uid())
    or exists (select 1 from public.athletes a
               join public.trainers t on t.id = a.trainer_id
               where a.id = messages.athlete_id and t.user_id = auth.uid())
  )
  with check (
    exists (select 1 from public.athletes a
            where a.id = messages.athlete_id and a.user_id = auth.uid())
    or exists (select 1 from public.athletes a
               join public.trainers t on t.id = a.trainer_id
               where a.id = messages.athlete_id and t.user_id = auth.uid())
  );

-- Enable Supabase Realtime so the chat view can .stream() live updates.
alter publication supabase_realtime add table public.messages;
