-- Applied to prod via Supabase MCP on 2026-09-20.
--
-- Two trainer-facing bugs with one root cause each:
--
-- 1. "Alumno no encontrado" when the trainer taps a new-student notification.
--    notify_first_login wrote the profile/user id into data.athlete_id, but
--    the dashboard opens StudentDetailScreen(studentId) which queries
--    athletes.id. Write the real athletes.id (+ keep student_id for reference).
--
-- 2. "Sin historial de entrenamientos" on the trainer's student-history screen.
--    workout_sessions only had an owner-only SELECT policy, so the trainer's
--    read returned zero rows. Add a trainer/admin read policy mirroring
--    check_ins_trainer_read.

CREATE OR REPLACE FUNCTION public.notify_first_login()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    IF OLD.first_login_at IS NULL AND NEW.first_login_at IS NOT NULL THEN
        -- Notify admins
        INSERT INTO notifications (user_id, type, title, message, data)
        SELECT id, 'first_login', 'Nuevo usuario activo',
               NEW.email || ' ha iniciado sesión por primera vez',
               jsonb_build_object('user_id', NEW.id)
        FROM profiles WHERE role = 'admin';

        -- Notify trainer if student (athlete_id must be athletes.id, not the
        -- profile id — the dashboard uses it to open the student detail)
        IF NEW.role = 'student' THEN
            INSERT INTO notifications (user_id, type, title, message, data)
            SELECT t.user_id, 'new_student', '¡Nuevo alumno activo!',
                   NEW.email || ' ha iniciado sesión',
                   jsonb_build_object('athlete_id', a.id, 'student_id', NEW.id)
            FROM athletes a
            JOIN trainers t ON a.trainer_id = t.id
            WHERE a.user_id = NEW.id;
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;

-- Backfill notifications whose athlete_id was mistakenly the profile/user id.
UPDATE public.notifications n
SET data = jsonb_set(n.data, '{athlete_id}', to_jsonb(a.id::text))
FROM public.athletes a
WHERE n.type = 'new_student'
  AND n.data->>'athlete_id' = a.user_id::text;

-- Trainer/admin read access to their athletes' workout sessions.
DROP POLICY IF EXISTS workout_sessions_trainer_read ON public.workout_sessions;
CREATE POLICY workout_sessions_trainer_read ON public.workout_sessions
  FOR SELECT TO authenticated
  USING (
    athlete_id IN (
      SELECT a.id FROM public.athletes a
      WHERE a.trainer_id = (SELECT private.my_trainer_id())
    )
    OR (SELECT private.get_role()) = 'admin'
  );
