-- Activa RLS en las 6 tablas sin proteger y define politicas por rol.
-- Ejecutar completo en el SQL Editor de Supabase.
-- Requiere columnas existentes: profiles.role ('admin'|'trainer'|'student'),
-- trainers.user_id, athletes.user_id, athletes.trainer_id, supplement_logs.athlete_id.

-- ==================== LIMPIEZA ====================
-- Existian politicas viejas/duplicadas con RLS apagado (p.ej. profiles_select
-- solo-propio-perfil, que romperia los joins de la app). Se eliminan todas
-- y se recrean coherentes abajo.
do $$
declare p record;
begin
  for p in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('profiles','athletes','invitations','invitation_tokens','trainer_subscriptions','supplement_logs')
  loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;

-- ==================== FUNCIONES AUXILIARES ====================
-- Schema privado: no queda expuesto por la API (PostgREST solo expone public).
-- SECURITY DEFINER evita recursion infinita al consultar profiles desde sus propias politicas.
create schema if not exists private;

create or replace function private.get_role()
returns text language sql stable security definer set search_path = '' as $$
  select role from public.profiles where id = (select auth.uid());
$$;

create or replace function private.my_trainer_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select id from public.trainers where user_id = (select auth.uid());
$$;

create or replace function private.my_athlete_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select id from public.athletes where user_id = (select auth.uid());
$$;

grant usage on schema private to authenticated;
grant execute on function private.get_role(), private.my_trainer_id(), private.my_athlete_id() to authenticated;

-- ==================== PROFILES ====================
alter table public.profiles enable row level security;

-- App invite-only: todos los usuarios autenticados ven los perfiles
-- (la app hace joins de profiles en trainers, notificaciones, etc.)
create policy "profiles_select" on public.profiles
  for select to authenticated using (true);

-- Insert: admin crea perfiles de trainers; un usuario solo puede crearse a si mismo
-- y nunca con rol elevado (bloquea auto-asignarse 'admin' en el signup).
create policy "profiles_insert" on public.profiles
  for insert to authenticated
  with check (
    (select private.get_role()) = 'admin'
    or (id = (select auth.uid()) and role = 'student')
  );

-- Update: propio perfil sin cambiar de rol, o admin.
create policy "profiles_update" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()) or (select private.get_role()) = 'admin')
  with check (
    (select private.get_role()) = 'admin'
    or (id = (select auth.uid()) and role = (select private.get_role()))
  );

create policy "profiles_delete" on public.profiles
  for delete to authenticated
  using ((select private.get_role()) = 'admin');

-- ==================== ATHLETES ====================
alter table public.athletes enable row level security;

create policy "athletes_select" on public.athletes
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or trainer_id = (select private.my_trainer_id())
    or (select private.get_role()) = 'admin'
  );

create policy "athletes_insert" on public.athletes
  for insert to authenticated
  with check (
    trainer_id = (select private.my_trainer_id())
    or (select private.get_role()) = 'admin'
  );

-- El alumno actualiza su propia fila (pasos, medidas, logs embebidos);
-- el trainer las de sus alumnos; admin todas.
create policy "athletes_update" on public.athletes
  for update to authenticated
  using (
    user_id = (select auth.uid())
    or trainer_id = (select private.my_trainer_id())
    or (select private.get_role()) = 'admin'
  )
  with check (
    user_id = (select auth.uid())
    or trainer_id = (select private.my_trainer_id())
    or (select private.get_role()) = 'admin'
  );

create policy "athletes_delete" on public.athletes
  for delete to authenticated
  using (
    trainer_id = (select private.my_trainer_id())
    or (select private.get_role()) = 'admin'
  );

-- ==================== INVITATIONS ====================
alter table public.invitations enable row level security;

create policy "invitations_staff" on public.invitations
  for all to authenticated
  using ((select private.get_role()) in ('admin', 'trainer'))
  with check ((select private.get_role()) in ('admin', 'trainer'));

-- ==================== INVITATION_TOKENS ====================
-- Solo admin. El flujo first-login pre-auth que leia esta tabla ya esta roto
-- por otra razon (auth.admin desde el cliente) y debe migrar a una Edge Function.
alter table public.invitation_tokens enable row level security;

create policy "invitation_tokens_admin" on public.invitation_tokens
  for all to authenticated
  using ((select private.get_role()) = 'admin')
  with check ((select private.get_role()) = 'admin');

-- ==================== TRAINER_SUBSCRIPTIONS ====================
alter table public.trainer_subscriptions enable row level security;

create policy "trainer_subscriptions_admin" on public.trainer_subscriptions
  for all to authenticated
  using ((select private.get_role()) = 'admin')
  with check ((select private.get_role()) = 'admin');

create policy "trainer_subscriptions_trainer_read" on public.trainer_subscriptions
  for select to authenticated
  using (trainer_id = (select private.my_trainer_id()));

-- ==================== SUPPLEMENT_LOGS ====================
alter table public.supplement_logs enable row level security;

-- El alumno gestiona sus propios logs.
create policy "supplement_logs_own" on public.supplement_logs
  for all to authenticated
  using (athlete_id = (select private.my_athlete_id()))
  with check (athlete_id = (select private.my_athlete_id()));

-- Trainer ve los logs de sus alumnos; admin todos.
create policy "supplement_logs_staff_read" on public.supplement_logs
  for select to authenticated
  using (
    athlete_id in (
      select id from public.athletes
      where trainer_id = (select private.my_trainer_id())
    )
    or (select private.get_role()) = 'admin'
  );

-- ==================== INDICES para columnas usadas en politicas ====================
create index if not exists idx_trainers_user_id on public.trainers (user_id);
create index if not exists idx_athletes_user_id on public.athletes (user_id);
create index if not exists idx_athletes_trainer_id on public.athletes (trainer_id);
create index if not exists idx_supplement_logs_athlete_id on public.supplement_logs (athlete_id);
create index if not exists idx_invitation_tokens_token on public.invitation_tokens (token);
