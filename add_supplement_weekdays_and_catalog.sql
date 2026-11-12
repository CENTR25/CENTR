-- W3 Supplements: specific weekdays + admin-managed quick-add catalog.
-- NOTE: the UI label "Diaria" was renamed to "Natural". The DB category key
-- stays 'diaria' on athlete_supplements (no data migration); supplement_catalog
-- uses the new key 'natural'. UI maps diaria <-> natural.

-- 1=Lunes .. 7=Domingo. null/empty => fall back to legacy `days` (todos|entreno|medio).
alter table public.athlete_supplements
  add column if not exists weekdays smallint[] null;
alter table public.athlete_supplements
  drop constraint if exists athlete_supplements_weekdays_check;
alter table public.athlete_supplements
  add constraint athlete_supplements_weekdays_check
  check (weekdays is null or weekdays <@ array[1,2,3,4,5,6,7]::smallint[]);

create table if not exists public.supplement_catalog (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null default 'natural' check (category in ('natural', 'quimica')),
  default_dose text,
  default_unit text,
  default_timing text[] not null default '{}',
  note text,
  is_active boolean not null default true,
  display_order integer not null default 0,
  created_by_trainer uuid references public.trainers(id) on delete cascade, -- null = global
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_supplement_catalog_trainer
  on public.supplement_catalog(created_by_trainer);

-- updated_at is set by the client on update (no shared public trigger fn exists).

alter table public.supplement_catalog enable row level security;

-- Read: globals + own entries (active), admin sees everything.
create policy supplement_catalog_read on public.supplement_catalog
  for select to authenticated
  using (
    (select private.get_role()) = 'admin'
    or (is_active and (created_by_trainer is null
        or created_by_trainer = (select private.my_trainer_id())))
    or created_by_trainer = (select private.my_trainer_id())
  );

create policy supplement_catalog_admin_write on public.supplement_catalog
  for all to authenticated
  using ((select private.get_role()) = 'admin')
  with check ((select private.get_role()) = 'admin');

create policy supplement_catalog_trainer_write on public.supplement_catalog
  for all to authenticated
  using (created_by_trainer is not null
         and created_by_trainer = (select private.my_trainer_id()))
  with check (created_by_trainer is not null
         and created_by_trainer = (select private.my_trainer_id()));

-- Seed: the previously hardcoded quick-add list.
insert into public.supplement_catalog (name, category, display_order)
select v.name, 'natural', v.ord
from (values ('Omega 3', 1), ('Multivitamínico', 2), ('Cafeína', 3)) as v(name, ord)
where not exists (
  select 1 from public.supplement_catalog c
  where c.created_by_trainer is null and lower(c.name) = lower(v.name));
