-- Mercado Pago billing (Phase 1): trainers pay PRGS monthly in ARS.
--
-- Design notes
--  * Payer-agnostic: a subscription row references a generic payer
--    (payer_user_id + payer_type). trainer_id stays for today's trainer flow
--    (Flutter + RLS keep working); consumer plans can be added later as DATA
--    (subscription_plans.audience = 'consumer', payer_type = 'consumer').
--  * ONE place for the access rule: private.billing_student_cap(trainer_id).
--    Relax "must have an active plan" later by editing only that function.
--  * "Current period end" = trainer_subscriptions.ends_at (paid-through date);
--    grace_until extends access after a failed charge.
--  * source = 'mp' | 'manual'. Edge Functions upsert ONLY by mp_preapproval_id /
--    external_reference and never touch source = 'manual' rows (admin comps).
--  * Billing writes come from Edge Functions (service role). The only client
--    write path left is the existing admin policy on trainer_subscriptions /
--    subscription_plans (admin manual assign + plan editor, Flutter admin UI).
--    mp_payments / mp_webhook_events have NO client write path at all.
-- Status: NOT applied to prod. Idempotent.

-- ---------------------------------------------------------------------------
-- 1. subscription_plans: audience + Mercado Pago columns
-- ---------------------------------------------------------------------------
alter table public.subscription_plans
  add column if not exists audience text not null default 'trainer',
  add column if not exists currency_id text not null default 'ARS',
  add column if not exists frequency integer not null default 1,
  add column if not exists frequency_type text not null default 'months',
  add column if not exists mp_plan_id text,
  add column if not exists mp_init_point text,
  add column if not exists mp_env text,
  add column if not exists price_is_placeholder boolean not null default false;

do $$ begin
  alter table public.subscription_plans
    add constraint subscription_plans_frequency_type_check
    check (frequency_type in ('days', 'months'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.subscription_plans
    add constraint subscription_plans_mp_env_check
    check (mp_env is null or mp_env in ('test', 'prod'));
exception when duplicate_object then null; end $$;

-- mp_plan_id differs per MP environment (test vs prod token).
create unique index if not exists subscription_plans_mp_plan_uidx
  on public.subscription_plans (mp_env, mp_plan_id) where mp_plan_id is not null;

-- ---------------------------------------------------------------------------
-- 2. trainer_subscriptions: generic payer + MP mirror
-- ---------------------------------------------------------------------------
alter table public.trainer_subscriptions
  add column if not exists payer_user_id uuid references public.profiles(id) on delete cascade,
  add column if not exists payer_type text not null default 'trainer',
  add column if not exists source text not null default 'manual',
  add column if not exists status text not null default 'authorized',
  add column if not exists mp_status text,
  add column if not exists mp_env text,
  add column if not exists mp_preapproval_id text,
  add column if not exists external_reference text,
  add column if not exists payer_email text,
  add column if not exists next_payment_date timestamptz,
  add column if not exists last_payment_at timestamptz,
  add column if not exists grace_until timestamptz,
  add column if not exists cancel_at_period_end boolean not null default false,
  add column if not exists canceled_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

-- trainer_id becomes optional so non-trainer payers can exist later.
alter table public.trainer_subscriptions alter column trainer_id drop not null;

do $$ begin
  alter table public.trainer_subscriptions
    add constraint trainer_subscriptions_source_check check (source in ('mp', 'manual'));
exception when duplicate_object then null; end $$;

-- Normalized status. DEFAULT 'authorized' + source 'manual' keep the existing
-- admin "assign plan" client insert working; Edge Functions always set both
-- explicitly (new MP rows start 'pending').
do $$ begin
  alter table public.trainer_subscriptions
    add constraint trainer_subscriptions_status_check
    check (status in ('pending', 'authorized', 'paused', 'past_due', 'cancelled', 'expired'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.trainer_subscriptions
    add constraint trainer_subscriptions_mp_env_check
    check (mp_env is null or mp_env in ('test', 'prod'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.trainer_subscriptions
    add constraint trainer_subscriptions_payer_check
    check (payer_type <> 'trainer' or trainer_id is not null);
exception when duplicate_object then null; end $$;

create unique index if not exists trainer_subscriptions_mp_preapproval_uidx
  on public.trainer_subscriptions (mp_preapproval_id) where mp_preapproval_id is not null;
create unique index if not exists trainer_subscriptions_external_ref_uidx
  on public.trainer_subscriptions (external_reference) where external_reference is not null;
create index if not exists trainer_subscriptions_trainer_idx
  on public.trainer_subscriptions (trainer_id);
create index if not exists trainer_subscriptions_payer_idx
  on public.trainer_subscriptions (payer_user_id);
create index if not exists trainer_subscriptions_plan_idx
  on public.trainer_subscriptions (plan_id);
create index if not exists athletes_trainer_id_idx
  on public.athletes (trainer_id);

-- Backfill payer from the trainer, and keep it filled for inserts that only
-- know trainer_id (e.g. the admin manual-assign client call).
update public.trainer_subscriptions s
   set payer_user_id = t.user_id
  from public.trainers t
 where s.trainer_id = t.id and s.payer_user_id is null;

create or replace function private.fill_subscription_payer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.payer_user_id is null and new.trainer_id is not null then
    select t.user_id into new.payer_user_id from public.trainers t where t.id = new.trainer_id;
  end if;
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function private.fill_subscription_payer() from public, anon, authenticated;

drop trigger if exists trainer_subscriptions_fill_payer on public.trainer_subscriptions;
create trigger trainer_subscriptions_fill_payer
  before insert or update on public.trainer_subscriptions
  for each row execute function private.fill_subscription_payer();

-- ---------------------------------------------------------------------------
-- 3. mp_payments + mp_webhook_events (service role only)
-- ---------------------------------------------------------------------------
create table if not exists public.mp_payments (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid references public.trainer_subscriptions(id) on delete set null,
  payer_user_id uuid references public.profiles(id) on delete set null,
  trainer_id uuid references public.trainers(id) on delete set null,
  mp_preapproval_id text,
  mp_payment_id text not null,
  mp_env text check (mp_env in ('test', 'prod')),
  amount numeric(12, 2),
  currency_id text not null default 'ARS',
  status text not null,
  status_detail text,
  paid_at timestamptz,
  raw jsonb,                      -- trimmed by the Edge Function, no card data
  created_at timestamptz not null default now(),
  constraint mp_payments_mp_payment_id_key unique (mp_payment_id)
);
create index if not exists mp_payments_subscription_idx on public.mp_payments (subscription_id);
create index if not exists mp_payments_payer_idx on public.mp_payments (payer_user_id);
create index if not exists mp_payments_trainer_idx on public.mp_payments (trainer_id);

create table if not exists public.mp_webhook_events (
  id uuid primary key default gen_random_uuid(),
  event_key text not null,        -- idempotency key, built by mp-webhook
  topic text,
  action text,
  resource_id text,
  request_id text,
  mp_env text check (mp_env in ('test', 'prod')),
  payload jsonb,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  error text,
  constraint mp_webhook_events_event_key_key unique (event_key)
);
create index if not exists mp_webhook_events_resource_idx on public.mp_webhook_events (resource_id);

-- ---------------------------------------------------------------------------
-- 4. RLS
-- ---------------------------------------------------------------------------
alter table public.mp_payments enable row level security;
alter table public.mp_webhook_events enable row level security;

-- Webhook log: RLS on, NO policies, no grants => service role only.
revoke all on public.mp_webhook_events from public, anon, authenticated;

-- Payments: read-only for the payer and admin. No write path for clients.
revoke all on public.mp_payments from public, anon, authenticated;
grant select on public.mp_payments to authenticated;

drop policy if exists mp_payments_payer_read on public.mp_payments;
create policy mp_payments_payer_read on public.mp_payments
  for select to authenticated
  using (payer_user_id = (select auth.uid()));

drop policy if exists mp_payments_admin_read on public.mp_payments;
create policy mp_payments_admin_read on public.mp_payments
  for select to authenticated
  using ((select private.get_role()) = 'admin');

-- Subscriptions: payer (trainer) reads own rows; admin policy
-- (trainer_subscriptions_admin, ALL) is kept for the manual-assign UI.
drop policy if exists trainer_subscriptions_trainer_read on public.trainer_subscriptions;
drop policy if exists trainer_subscriptions_payer_read on public.trainer_subscriptions;
create policy trainer_subscriptions_payer_read on public.trainer_subscriptions
  for select to authenticated
  using (
    payer_user_id = (select auth.uid())
    or trainer_id = (select private.my_trainer_id())
  );

-- Billing tables were readable/writable by anon at the grant level (RLS only).
revoke all on public.trainer_subscriptions from anon;
revoke all on public.subscription_plans from anon;

-- ---------------------------------------------------------------------------
-- 5. Access rule in ONE place: student cap per trainer
-- ---------------------------------------------------------------------------
-- Returns the max number of students the trainer may have. NULL = unlimited.
-- Access = subscription is_active, not 'pending', and now() is before
-- greatest(ends_at, grace_until). (cancelled/paused keep access until the
-- paid-through date.) No access => default free cap of 10.
-- To relax the "must have an active plan" rule later, change ONLY this function.
create or replace function private.billing_student_cap(p_trainer_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_default constant integer := 10;
  v_found boolean := false;
  v_cap integer;
  v_unlimited boolean := false;
  r record;
begin
  for r in
    select p.max_students
      from public.trainer_subscriptions s
      join public.subscription_plans p on p.id = s.plan_id
     where s.trainer_id = p_trainer_id
       and s.is_active
       and s.status <> 'pending'
       and now() < greatest(s.ends_at, coalesce(s.grace_until, s.ends_at))
  loop
    v_found := true;
    if r.max_students is null then
      v_unlimited := true;
    else
      v_cap := greatest(coalesce(v_cap, 0), r.max_students);
    end if;
  end loop;

  if not v_found then
    return v_default;
  end if;
  if v_unlimited then
    return null;
  end if;
  return v_cap;
end;
$$;
revoke all on function private.billing_student_cap(uuid) from public, anon, authenticated;

-- Student cap trigger: blocks adding a student (insert, or re-assigning to a
-- different trainer) beyond the trainer's cap. Existing students are never
-- removed; over-cap trainers just cannot add more.
create or replace function private.enforce_max_students()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cap integer;
  v_count integer;
begin
  if new.trainer_id is null then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.trainer_id is not distinct from old.trainer_id then
    return new;
  end if;

  -- Serialize concurrent inserts for the same trainer.
  perform pg_advisory_xact_lock(hashtextextended(new.trainer_id::text, 0));

  v_cap := private.billing_student_cap(new.trainer_id);
  if v_cap is null then
    return new;
  end if;

  select count(*) into v_count from public.athletes a where a.trainer_id = new.trainer_id;
  if v_count >= v_cap then
    raise exception 'Alcanzaste el limite de % alumnos de tu plan. Mejora tu plan para agregar mas alumnos.', v_cap
      using errcode = 'check_violation',
            detail = 'student_limit_reached',
            hint = 'upgrade_plan';
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_max_students() from public, anon, authenticated;

drop trigger if exists athletes_enforce_max_students on public.athletes;
create trigger athletes_enforce_max_students
  before insert or update of trainer_id on public.athletes
  for each row execute function private.enforce_max_students();

-- ---------------------------------------------------------------------------
-- 6. Plans: three ARS plans by student cap (inactive, no mp_plan_id yet)
-- ---------------------------------------------------------------------------
-- Existing rows (Basico/Profesional/Empresarial, USD-looking prices) are
-- converted in place so trainer_subscriptions.plan_id FKs stay valid.
-- Prices confirmed by Alan 2026-11-23: 40000 / 75000 / 100000 ARS.
-- is_active = false until the mp-admin Edge Function creates the MP plans.
update public.subscription_plans set
  price = 40000, currency_id = 'ARS', max_students = 10, duration_days = 30,
  audience = 'trainer', is_active = false, price_is_placeholder = false
where name = 'Plan Básico';

update public.subscription_plans set
  price = 75000, currency_id = 'ARS', max_students = 50, duration_days = 30,
  audience = 'trainer', is_active = false, price_is_placeholder = false
where name = 'Plan Profesional';

update public.subscription_plans set
  price = 100000, currency_id = 'ARS', max_students = 100, duration_days = 30,
  audience = 'trainer', is_active = false, price_is_placeholder = false
where name = 'Plan Empresarial';

insert into public.subscription_plans
  (name, price, currency_id, duration_days, max_students, features, is_active, audience, price_is_placeholder)
select v.name, v.price, 'ARS', 30, v.cap, '{}'::jsonb, false, 'trainer', v.ph
from (values
  ('Plan Básico', 40000::numeric, 10, false),
  ('Plan Profesional', 75000::numeric, 50, false),
  ('Plan Empresarial', 100000::numeric, 100, false)
) as v(name, price, cap, ph)
where not exists (select 1 from public.subscription_plans p where p.name = v.name);

-- ---------------------------------------------------------------------------
-- 7. Grandfather trainers already over the free cap (do NOT lock anyone out)
-- ---------------------------------------------------------------------------
-- Any trainer with more than 10 students and no valid access gets a manual
-- comp subscription on the 100-student plan until 2027-01-31 (admin can edit
-- or replace it; manual rows are never touched by webhooks).
do $$
declare
  v_plan uuid;
  r record;
begin
  select id into v_plan from public.subscription_plans
   where name = 'Plan Empresarial' and audience = 'trainer' order by created_at limit 1;

  for r in
    select t.id as trainer_id
      from public.trainers t
     where (select count(*) from public.athletes a where a.trainer_id = t.id) > 10
       and private.billing_student_cap(t.id) = 10
  loop
    update public.trainer_subscriptions s
       set plan_id = v_plan, is_active = true, source = 'manual', status = 'authorized',
           ends_at = timestamptz '2027-01-31 23:59:59+00'
     where s.id = (
       select id from public.trainer_subscriptions
        where trainer_id = r.trainer_id order by ends_at desc limit 1);
    if not found then
      insert into public.trainer_subscriptions
        (trainer_id, plan_id, starts_at, ends_at, is_active, source, status)
      values (r.trainer_id, v_plan, now(), timestamptz '2027-01-31 23:59:59+00', true, 'manual', 'authorized');
    end if;
  end loop;
end $$;
