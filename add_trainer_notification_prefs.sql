-- add_trainer_notification_prefs.sql
-- Per-trainer notification preferences surfaced in the Configuración screen.
-- These are stored now; real push/email delivery (a later phase) reads these
-- columns to decide whether to fan out each event type to a trainer.
--
-- Keyed on the auth user id (one row per trainer user), consistent with how
-- other per-user data (check_ins) keys on user_id rather than trainers.id.

create table if not exists public.trainer_notification_prefs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  workout_completed boolean not null default true,  -- "Alumno completó entrenamiento"
  inactive_7d       boolean not null default false, -- "Alumnos inactivo +7 días"
  student_message   boolean not null default true,  -- "Mensaje de alumnos"
  prgs_news         boolean not null default false, -- "Novedades PRGS"
  updated_at timestamptz not null default now()
);

alter table public.trainer_notification_prefs enable row level security;

-- A trainer can only read and write their own preference row.
drop policy if exists "notif_prefs_select_own" on public.trainer_notification_prefs;
create policy "notif_prefs_select_own"
  on public.trainer_notification_prefs for select
  using (auth.uid() = user_id);

drop policy if exists "notif_prefs_insert_own" on public.trainer_notification_prefs;
create policy "notif_prefs_insert_own"
  on public.trainer_notification_prefs for insert
  with check (auth.uid() = user_id);

drop policy if exists "notif_prefs_update_own" on public.trainer_notification_prefs;
create policy "notif_prefs_update_own"
  on public.trainer_notification_prefs for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
