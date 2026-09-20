-- Server-side creation of profile + athlete rows at signup.
-- Fixes RLS 42501 during invite signup: the client has no session yet
-- (email confirmation pending), and athletes_insert never allowed students
-- to insert their own row. Only fires for public student signups; the
-- admin-auth Edge Function creates trainers with role 'trainer' in metadata
-- and keeps inserting its own rows.
-- Applied to prod via Supabase MCP on 2026-09-20.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta_trainer uuid;
begin
  -- Only public student signups; trainer/admin users are provisioned by the
  -- admin-auth Edge Function which manages its own rows.
  if coalesce(new.raw_user_meta_data->>'role', '') <> 'student' then
    return new;
  end if;

  insert into public.profiles (id, email, role, is_active)
  values (new.id, coalesce(new.email, ''), 'student', true)
  on conflict (id) do nothing;

  -- trainer_id comes from the invite URL via signUp metadata: it is untrusted,
  -- so only link it when it references an existing trainer.
  begin
    meta_trainer := (new.raw_user_meta_data->>'trainer_id')::uuid;
  exception when others then
    meta_trainer := null;
  end;
  if meta_trainer is not null
     and not exists (select 1 from public.trainers t where t.id = meta_trainer) then
    meta_trainer := null;
  end if;

  if not exists (select 1 from public.athletes a where a.user_id = new.id) then
    insert into public.athletes (user_id, name, trainer_id)
    values (
      new.id,
      coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), coalesce(new.email, 'Alumno')),
      meta_trainer
    );
  end if;

  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
