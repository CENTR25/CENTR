-- Unifica el valor de rol 'athlete' -> 'student'.
-- El constraint permitia 'athlete' pero la app usa 'student' como canonico
-- (app_constants.dart), y las politicas RLS ya validan 'student'.

-- 1. Quitar el constraint viejo para poder migrar los datos
alter table public.profiles drop constraint profiles_role_check;

-- 2. Migrar filas existentes (habia 1 usuario con role='athlete')
update public.profiles set role = 'student' where role = 'athlete';

-- 3. Nuevo constraint con el set canonico
alter table public.profiles add constraint profiles_role_check
  check (role = any (array['admin'::text, 'trainer'::text, 'student'::text]));

-- 4. notify_first_login (trigger activo on_first_login): comparaba role='athlete'
create or replace function public.notify_first_login()
returns trigger language plpgsql security definer set search_path = public as $$
BEGIN
    IF OLD.first_login_at IS NULL AND NEW.first_login_at IS NOT NULL THEN
        -- Notify admins
        INSERT INTO notifications (user_id, type, title, message, data)
        SELECT id, 'first_login', 'Nuevo usuario activo',
               NEW.email || ' ha iniciado sesión por primera vez',
               jsonb_build_object('user_id', NEW.id)
        FROM profiles WHERE role = 'admin';

        -- Notify trainer if student
        IF NEW.role = 'student' THEN
            INSERT INTO notifications (user_id, type, title, message, data)
            SELECT t.user_id, 'new_student', '¡Nuevo alumno activo!',
                   NEW.email || ' ha iniciado sesión',
                   jsonb_build_object('athlete_id', NEW.id)
            FROM athletes a
            JOIN trainers t ON a.trainer_id = t.id
            WHERE a.user_id = NEW.id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

-- 5. handle_new_user: sin trigger asociado hoy (funcion muerta), pero se
--    corrige para que no reintroduzca 'athlete' si se reactiva.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
BEGIN
    INSERT INTO profiles (id, email, role)
    VALUES (NEW.id, NEW.email, 'student')
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;
