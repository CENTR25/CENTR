-- 24h renewal buffer for MP-sourced healthy rows: a late charge / delayed
-- webhook must not cut a paying trainer's access the instant ends_at passes.
-- Manual rows and non-'authorized' states are unchanged. Only the access
-- expression differs from add_mp_billing.sql.
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
       and now() < greatest(
             s.ends_at + case when s.source = 'mp' and s.status = 'authorized'
                              then interval '24 hours' else interval '0' end,
             coalesce(s.grace_until, s.ends_at))
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
