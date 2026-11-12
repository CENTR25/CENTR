-- Muscle-group catalog (ADR-007). Exercises keep their TEXT value in
-- exercises.muscle_group / exercises.category; this table only drives the
-- filter chips and create-exercise picker. Rename goes through an RPC that
-- updates matching exercises the actor may edit, so nothing is orphaned.
create table if not exists public.muscle_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  display_order int not null default 0,
  is_active boolean not null default true,
  created_by_trainer uuid references public.trainers(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- unique case-insensitive per scope (global scope and per trainer)
create unique index if not exists muscle_groups_name_scope_uq
  on public.muscle_groups (lower(name), coalesce(created_by_trainer, '00000000-0000-0000-0000-000000000000'::uuid));

alter table public.muscle_groups enable row level security;

create policy muscle_groups_select on public.muscle_groups for select to authenticated
  using (
    created_by_trainer is null
    or created_by_trainer = (select private.my_trainer_id())
    or (select private.get_role()) = 'admin'
    or created_by_trainer = (select trainer_id from public.athletes where user_id = auth.uid())
  );
create policy muscle_groups_insert on public.muscle_groups for insert to authenticated
  with check (
    (created_by_trainer is null and (select private.get_role()) = 'admin')
    or (created_by_trainer is not null and created_by_trainer = (select private.my_trainer_id()))
  );
create policy muscle_groups_update on public.muscle_groups for update to authenticated
  using (
    (created_by_trainer is null and (select private.get_role()) = 'admin')
    or (created_by_trainer is not null and created_by_trainer = (select private.my_trainer_id()))
  )
  with check (
    (created_by_trainer is null and (select private.get_role()) = 'admin')
    or (created_by_trainer is not null and created_by_trainer = (select private.my_trainer_id()))
  );
create policy muscle_groups_delete on public.muscle_groups for delete to authenticated
  using (
    (created_by_trainer is null and (select private.get_role()) = 'admin')
    or (created_by_trainer is not null and created_by_trainer = (select private.my_trainer_id()))
  );

-- Seed global groups from distinct live values (canonical Spanish spellings).
insert into public.muscle_groups (name, display_order) values
  ('Pecho',1),('Espalda',2),('Piernas',3),('Hombros',4),('Brazos',5),
  ('Bíceps',6),('Tríceps',7),('Antebrazos',8),('Trapecio',9),
  ('Gemelos',10),('Abdominales',11)
on conflict do nothing;

-- Safe rename: updates exercises text values the actor may edit.
create or replace function public.rename_muscle_group(p_id uuid, p_new_name text)
returns void language plpgsql security definer set search_path = public as $$
declare g public.muscle_groups; v_new text := btrim(p_new_name);
begin
  if v_new = '' then raise exception 'Nombre vacío'; end if;
  select * into g from public.muscle_groups where id = p_id;
  if not found then raise exception 'Grupo no encontrado'; end if;
  if g.created_by_trainer is null then
    if private.get_role() <> 'admin' then raise exception 'No autorizado'; end if;
  elsif g.created_by_trainer is distinct from private.my_trainer_id() then
    raise exception 'No autorizado';
  end if;
  update public.muscle_groups set name = v_new, updated_at = now() where id = p_id;
  if g.created_by_trainer is null then
    update public.exercises set muscle_group = v_new where lower(muscle_group) = lower(g.name);
    update public.exercises set category = v_new where lower(category) = lower(g.name);
  else
    update public.exercises set muscle_group = v_new
      where lower(muscle_group) = lower(g.name) and created_by_trainer = g.created_by_trainer;
    update public.exercises set category = v_new
      where lower(category) = lower(g.name) and created_by_trainer = g.created_by_trainer;
  end if;
end $$;
revoke all on function public.rename_muscle_group(uuid, text) from public, anon;
grant execute on function public.rename_muscle_group(uuid, text) to authenticated;
