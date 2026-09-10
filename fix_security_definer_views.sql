-- Las vistas trainer_stats y athlete_rankings estaban en modo SECURITY DEFINER
-- (por defecto en Postgres): saltaban el RLS de las tablas subyacentes para
-- cualquier usuario que las consultara. security_invoker hace que apliquen
-- las politicas RLS del usuario que consulta. Ninguna se usa aun en la app.
alter view public.trainer_stats set (security_invoker = true);
alter view public.athlete_rankings set (security_invoker = true);
