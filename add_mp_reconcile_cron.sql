-- Nightly MP reconcile. NO secret value here: the job reads vault secret
-- 'mp_cron_secret' at run time (must equal the CRON_SECRET Edge Function secret).
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'mp-reconcile-nightly') then
    perform cron.unschedule('mp-reconcile-nightly');
  end if;
end $$;

-- 06:00 UTC = 03:00 Argentina
select cron.schedule('mp-reconcile-nightly', '0 6 * * *', $job$
  select net.http_post(
    url := 'https://wtvjpxvcarclkxstmefr.supabase.co/functions/v1/mp-reconcile',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'mp_cron_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 55000);
$job$);
