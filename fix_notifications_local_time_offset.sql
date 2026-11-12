-- Notifications created by the client were stamped with an offset-less local
-- time (DateTime.now().toIso8601String()), which Postgres stored as UTC — so on
-- Argentina devices (UTC-3) every client-created notification is 3h early.
-- Verified 2026-11-12: 22/25 workoutCompleted rows sit exactly 3.00h before
-- their workout_sessions.created_at.
--
-- 1) Server owns the timestamp from now on: force created_at = now() on insert,
--    so old app builds that still send a local created_at can't reintroduce it.
-- 2) Backfill existing client-created rows (+3h). Rows written by the
--    notify_first_login trigger ('first_login', 'new_student') already used
--    now() and are left alone. Running this file twice would double-shift:
--    the UPDATE is guarded to rows created before the trigger existed.

CREATE OR REPLACE FUNCTION public.notifications_force_server_created_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.created_at := now();
  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'notifications_server_created_at'
      AND tgrelid = 'public.notifications'::regclass
  ) THEN
    UPDATE public.notifications
    SET created_at = created_at + interval '3 hours'
    WHERE type NOT IN ('first_login', 'new_student');

    CREATE TRIGGER notifications_server_created_at
      BEFORE INSERT ON public.notifications
      FOR EACH ROW EXECUTE FUNCTION public.notifications_force_server_created_at();
  END IF;
END;
$$;
