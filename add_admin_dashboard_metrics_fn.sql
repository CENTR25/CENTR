-- Migration: admin dashboard metrics RPC
-- Applied: 2026-10-30
-- Single round-trip for the admin Inicio "Panel PRGS" header cards.
-- SECURITY DEFINER so the aggregate reads trainer_subscriptions/athletes
-- without tripping per-row RLS; gated to admins via private.get_role().

CREATE OR REPLACE FUNCTION public.admin_dashboard_metrics()
RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN (SELECT private.get_role()) <> 'admin' THEN
      json_build_object(
        'ingresos_mes', 0,
        'suscripciones_activas', 0,
        'total_trainers', 0,
        'total_alumnos', 0
      )
    ELSE
      json_build_object(
        'ingresos_mes', COALESCE((
          SELECT SUM(p.price)
          FROM trainer_subscriptions ts
          JOIN subscription_plans p ON p.id = ts.plan_id
          WHERE ts.is_active AND ts.ends_at > now()
        ), 0),
        'suscripciones_activas', (
          SELECT count(*) FROM trainer_subscriptions
          WHERE is_active AND ends_at > now()
        ),
        'total_trainers', (SELECT count(*) FROM trainers),
        'total_alumnos', (SELECT count(*) FROM athletes)
      )
  END;
$$;

-- Only authenticated callers; the body itself enforces admin-only data.
REVOKE ALL ON FUNCTION public.admin_dashboard_metrics() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_metrics() TO authenticated;
