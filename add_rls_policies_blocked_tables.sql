-- Politicas para las 7 tablas que tenian RLS habilitado SIN politicas
-- (achievements, articles, body_progress, leaderboard_entries, streaks,
-- subscriptions, workout_logs) — estaban bloqueadas para toda la app.
-- Usa los helpers private.* creados en enable_rls_policies.sql.

-- ==================== ACHIEVEMENTS (athlete_id) ====================
-- Lectura: el alumno las suyas, trainer las de sus alumnos. Escritura: sistema/admin.
create policy "achievements_select" on public.achievements
  for select to authenticated
  using (
    athlete_id = (select private.my_athlete_id())
    or athlete_id in (select id from public.athletes where trainer_id = (select private.my_trainer_id()))
    or (select private.get_role()) = 'admin'
  );

create policy "achievements_admin" on public.achievements
  for all to authenticated
  using ((select private.get_role()) = 'admin')
  with check ((select private.get_role()) = 'admin');

-- ==================== ARTICLES (trainer_id, is_published) ====================
-- Publicados: visibles para todos los autenticados. El trainer gestiona los suyos.
create policy "articles_select_published" on public.articles
  for select to authenticated
  using (
    is_published = true
    or trainer_id = (select private.my_trainer_id())
    or (select private.get_role()) = 'admin'
  );

create policy "articles_trainer_manage" on public.articles
  for all to authenticated
  using (
    trainer_id = (select private.my_trainer_id())
    or (select private.get_role()) = 'admin'
  )
  with check (
    trainer_id = (select private.my_trainer_id())
    or (select private.get_role()) = 'admin'
  );

-- ==================== BODY_PROGRESS (athlete_id) ====================
create policy "body_progress_own" on public.body_progress
  for all to authenticated
  using (athlete_id = (select private.my_athlete_id()))
  with check (athlete_id = (select private.my_athlete_id()));

create policy "body_progress_staff" on public.body_progress
  for select to authenticated
  using (
    athlete_id in (select id from public.athletes where trainer_id = (select private.my_trainer_id()))
    or (select private.get_role()) = 'admin'
  );

create policy "body_progress_admin_write" on public.body_progress
  for all to authenticated
  using ((select private.get_role()) = 'admin')
  with check ((select private.get_role()) = 'admin');

-- ==================== LEADERBOARD_ENTRIES (trainer_id, athlete_id) ====================
-- Todo el grupo del trainer ve su leaderboard (incluye a los alumnos del grupo).
create policy "leaderboard_select_group" on public.leaderboard_entries
  for select to authenticated
  using (
    trainer_id = (select private.my_trainer_id())
    or trainer_id = (select trainer_id from public.athletes where user_id = (select auth.uid()))
    or (select private.get_role()) = 'admin'
  );

-- Escritura: sistema/admin (los rankings se calculan, no los edita el usuario).
create policy "leaderboard_admin_write" on public.leaderboard_entries
  for all to authenticated
  using ((select private.get_role()) = 'admin')
  with check ((select private.get_role()) = 'admin');

-- ==================== STREAKS (athlete_id) ====================
create policy "streaks_own" on public.streaks
  for all to authenticated
  using (athlete_id = (select private.my_athlete_id()))
  with check (athlete_id = (select private.my_athlete_id()));

create policy "streaks_staff_read" on public.streaks
  for select to authenticated
  using (
    athlete_id in (select id from public.athletes where trainer_id = (select private.my_trainer_id()))
    or (select private.get_role()) = 'admin'
  );

-- ==================== SUBSCRIPTIONS (trainer_id) ====================
-- Mismo modelo que trainer_subscriptions: admin gestiona, trainer lee la suya.
create policy "subscriptions_admin" on public.subscriptions
  for all to authenticated
  using ((select private.get_role()) = 'admin')
  with check ((select private.get_role()) = 'admin');

create policy "subscriptions_trainer_read" on public.subscriptions
  for select to authenticated
  using (trainer_id = (select private.my_trainer_id()));

-- ==================== WORKOUT_LOGS (athlete_id) ====================
create policy "workout_logs_own" on public.workout_logs
  for all to authenticated
  using (athlete_id = (select private.my_athlete_id()))
  with check (athlete_id = (select private.my_athlete_id()));

create policy "workout_logs_staff_read" on public.workout_logs
  for select to authenticated
  using (
    athlete_id in (select id from public.athletes where trainer_id = (select private.my_trainer_id()))
    or (select private.get_role()) = 'admin'
  );

-- ==================== INDICES para columnas usadas en politicas ====================
create index if not exists idx_achievements_athlete_id on public.achievements (athlete_id);
create index if not exists idx_articles_trainer_id on public.articles (trainer_id);
create index if not exists idx_body_progress_athlete_id on public.body_progress (athlete_id);
create index if not exists idx_leaderboard_entries_trainer_id on public.leaderboard_entries (trainer_id);
create index if not exists idx_streaks_athlete_id on public.streaks (athlete_id);
create index if not exists idx_subscriptions_trainer_id on public.subscriptions (trainer_id);
create index if not exists idx_workout_logs_athlete_id on public.workout_logs (athlete_id);
