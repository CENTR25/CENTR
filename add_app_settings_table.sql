-- Global key/value app settings, admin-managed.
--
-- First use: `recipes_enabled` — a master switch for the student "Recetario
-- oficial" card. The recetario is not implemented yet, so it ships disabled
-- and the admin can flip it on from Contenido → Recetas once it's ready.
--
-- RLS: any authenticated user can READ (students need recipes_enabled to decide
-- whether to render the card); only admins can WRITE.

CREATE TABLE IF NOT EXISTS public.app_settings (
  key        text PRIMARY KEY,
  value      jsonb NOT NULL DEFAULT 'null'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_settings_read ON public.app_settings;
CREATE POLICY app_settings_read ON public.app_settings
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS app_settings_admin_write ON public.app_settings;
CREATE POLICY app_settings_admin_write ON public.app_settings
  FOR ALL TO authenticated
  USING ((SELECT private.get_role()) = 'admin')
  WITH CHECK ((SELECT private.get_role()) = 'admin');

-- Seed the recetario switch as OFF (feature not yet implemented).
INSERT INTO public.app_settings (key, value)
VALUES ('recipes_enabled', 'false'::jsonb)
ON CONFLICT (key) DO NOTHING;
