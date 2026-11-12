-- Review fixes for the Nov 13 batch.
-- F1: a global muscle group rename must not rewrite trainers' private exercises.
create or replace function public.rename_muscle_group(p_id uuid, p_new_name text)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare g public.muscle_groups; v_new text := btrim(coalesce(p_new_name, ''));
begin
  if v_new = '' then raise exception 'Nombre vacío'; end if;
  if char_length(v_new) > 100 then raise exception 'Nombre demasiado largo'; end if;
  select * into g from public.muscle_groups where id = p_id;
  if not found then raise exception 'Grupo no encontrado'; end if;
  if g.created_by_trainer is null then
    if private.get_role() <> 'admin' then raise exception 'No autorizado'; end if;
  elsif g.created_by_trainer is distinct from private.my_trainer_id() then
    raise exception 'No autorizado';
  end if;
  update public.muscle_groups set name = v_new, updated_at = now() where id = p_id;
  if g.created_by_trainer is null then
    update public.exercises set muscle_group = v_new
      where lower(muscle_group) = lower(g.name) and created_by_trainer is null;
    update public.exercises set category = v_new
      where lower(category) = lower(g.name) and created_by_trainer is null;
  else
    update public.exercises set muscle_group = v_new
      where lower(muscle_group) = lower(g.name) and created_by_trainer = g.created_by_trainer;
    update public.exercises set category = v_new
      where lower(category) = lower(g.name) and created_by_trainer = g.created_by_trainer;
  end if;
end $function$;

-- F3: default_meals SELECT scoped like foods (global + own + athlete's trainer + admin).
drop policy if exists "Meals are viewable by everyone" on public.default_meals;
drop policy if exists default_meals_select on public.default_meals;
create policy default_meals_select on public.default_meals for select to authenticated
using (
  created_by_trainer is null
  or created_by_trainer = (select private.my_trainer_id())
  or (select private.get_role()) = 'admin'
  or created_by_trainer = (select a.trainer_id from public.athletes a where a.user_id = (select auth.uid()))
);

-- F4: basic length constraints.
alter table public.muscle_groups drop constraint if exists muscle_groups_name_len;
alter table public.muscle_groups add constraint muscle_groups_name_len
  check (char_length(btrim(name)) between 1 and 100) not valid;
alter table public.supplement_catalog drop constraint if exists supplement_catalog_name_len;
alter table public.supplement_catalog add constraint supplement_catalog_name_len
  check (char_length(btrim(name)) between 1 and 200) not valid;
