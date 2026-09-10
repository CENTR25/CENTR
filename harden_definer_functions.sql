-- Endurece las 6 funciones SECURITY DEFINER heredadas:
-- 1) Fija search_path = public (los cuerpos usan tablas sin calificar; fijar ''
--    las romperia). Evita hijacking del search_path del caller.
-- 2) Revoca EXECUTE a PUBLIC/anon/authenticated: ninguna se llama desde la app
--    y en modo definer saltan RLS si se invocan via /rest/v1/rpc/.
--    Las 3 funciones de trigger (handle_new_user, notify_first_login,
--    update_workout_streak) siguen funcionando: los triggers no dependen del
--    privilegio EXECUTE del usuario final.

alter function public.handle_new_user() set search_path = public;
alter function public.notify_first_login() set search_path = public;
alter function public.update_workout_streak() set search_path = public;
alter function public.create_invitation_token(uuid, text, timestamptz) set search_path = public;
alter function public.is_trainer_subscription_active(uuid) set search_path = public;
alter function public.get_trainer_active_subscription(uuid) set search_path = public;

revoke execute on function
  public.handle_new_user(),
  public.notify_first_login(),
  public.update_workout_streak(),
  public.create_invitation_token(uuid, text, timestamptz),
  public.is_trainer_subscription_active(uuid),
  public.get_trainer_active_subscription(uuid)
from public, anon, authenticated;
