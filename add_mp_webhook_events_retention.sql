-- Retention for mp_webhook_events: delete rows older than 90 days, daily.
-- No secrets. Idempotent (unschedules the same-named job first).
create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'mp-webhook-events-retention') then
    perform cron.unschedule('mp-webhook-events-retention');
  end if;
end $$;

-- 07:00 UTC daily (after the 06:00 reconcile)
select cron.schedule('mp-webhook-events-retention', '0 7 * * *', $job$
  delete from public.mp_webhook_events where received_at < now() - interval '90 days';
$job$);
