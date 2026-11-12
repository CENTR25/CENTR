-- ADR-006: ingredient-level food bank (per serving, default 100 g) + write
-- policies/ownership for default_meals. created_by_trainer NULL = global
-- (admin-managed); otherwise owned by that trainer.

create table if not exists public.foods (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 200),
  category text not null default 'Otros' check (category in (
    'Proteínas','Carbohidratos y cereales','Frutas','Verduras',
    'Grasas y aceites','Frutos secos','Lácteos','Suplementos deportivos',
    'Preparados','Productos argentinos','Otros')),
  state text check (state is null or char_length(state) <= 100),
  calories numeric not null default 0 check (calories >= 0 and calories <= 2000),
  protein numeric not null default 0 check (protein >= 0 and protein <= 200),
  carbs numeric not null default 0 check (carbs >= 0 and carbs <= 200),
  fat numeric not null default 0 check (fat >= 0 and fat <= 200),
  fiber numeric not null default 0 check (fiber >= 0 and fiber <= 200),
  serving_size numeric not null default 100 check (serving_size > 0 and serving_size <= 10000),
  serving_unit text not null default 'g' check (char_length(serving_unit) <= 20),
  source text,
  verified boolean not null default false,
  brand text,
  barcode text,
  created_by_trainer uuid references public.trainers(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists foods_unique_name_state_owner
  on public.foods (lower(name), coalesce(state, ''),
    coalesce(created_by_trainer, '00000000-0000-0000-0000-000000000000'::uuid));
create index if not exists idx_foods_category on public.foods (category);
create index if not exists idx_foods_created_by_trainer on public.foods (created_by_trainer);

alter table public.foods enable row level security;

drop policy if exists foods_select on public.foods;
create policy foods_select on public.foods for select to authenticated
using (
  created_by_trainer is null
  or created_by_trainer = (select private.my_trainer_id())
  or (select private.get_role()) = 'admin'
  or created_by_trainer = (select a.trainer_id from public.athletes a where a.user_id = (select auth.uid()))
);

drop policy if exists foods_insert on public.foods;
create policy foods_insert on public.foods for insert to authenticated
with check (
  (created_by_trainer is null and (select private.get_role()) = 'admin')
  or (created_by_trainer is not null and created_by_trainer = (select private.my_trainer_id()))
);

drop policy if exists foods_update on public.foods;
create policy foods_update on public.foods for update to authenticated
using (
  (created_by_trainer is null and (select private.get_role()) = 'admin')
  or created_by_trainer = (select private.my_trainer_id())
)
with check (
  (created_by_trainer is null and (select private.get_role()) = 'admin')
  or created_by_trainer = (select private.my_trainer_id())
);

drop policy if exists foods_delete on public.foods;
create policy foods_delete on public.foods for delete to authenticated
using (
  (created_by_trainer is null and (select private.get_role()) = 'admin')
  or created_by_trainer = (select private.my_trainer_id())
);

-- default_meals: ownership + write policies (existing SELECT policy kept).
alter table public.default_meals
  add column if not exists created_by_trainer uuid references public.trainers(id) on delete cascade;
create index if not exists idx_default_meals_created_by_trainer
  on public.default_meals (created_by_trainer);

drop policy if exists default_meals_insert on public.default_meals;
create policy default_meals_insert on public.default_meals for insert to authenticated
with check (
  (created_by_trainer is null and (select private.get_role()) = 'admin')
  or (created_by_trainer is not null and created_by_trainer = (select private.my_trainer_id()))
);
drop policy if exists default_meals_update on public.default_meals;
create policy default_meals_update on public.default_meals for update to authenticated
using (
  (created_by_trainer is null and (select private.get_role()) = 'admin')
  or created_by_trainer = (select private.my_trainer_id())
)
with check (
  (created_by_trainer is null and (select private.get_role()) = 'admin')
  or created_by_trainer = (select private.my_trainer_id())
);
drop policy if exists default_meals_delete on public.default_meals;
create policy default_meals_delete on public.default_meals for delete to authenticated
using (
  (created_by_trainer is null and (select private.get_role()) = 'admin')
  or created_by_trainer = (select private.my_trainer_id())
);

-- Seed: 35 global protein foods per 100 g (idempotent via the unique index).
insert into public.foods (name, category, state, calories, protein, carbs, fat, serving_size, serving_unit, source, verified)
select v.name, 'Proteínas', v.state, v.kcal, v.p, v.c, v.f, 100, 'g', 'seed', false
from (values
('Pechuga de pollo','Cruda',120,22.5,0,2.6),
('Pechuga de pollo','Cocida',165,31,0,3.6),
('Muslo de pollo sin piel','Crudo',121,19.7,0,4.1),
('Carne vacuna magra','Cruda',137,21.4,0,5),
('Carne picada 95% magra','Cruda',137,21.4,0,5),
('Carne vacuna magra','Cocida',217,26.1,0,11.8),
('Lomo de cerdo','Crudo',143,21,0,6),
('Solomillo de cerdo','Cocido',143,26.2,0,3.5),
('Pechuga de pavo','Cruda',114,23.7,0,1.5),
('Atún al natural','Escurrido',116,25.5,0,0.8),
('Atún fresco','Crudo',132,28.2,0,0.6),
('Salmón','Crudo',208,20.4,0,13.4),
('Merluza','Cruda',90,18.3,0,1.2),
('Bacalao','Crudo',82,17.8,0,0.7),
('Sardinas','En conserva escurridas',208,24.6,0,11.5),
('Langostinos','Crudos',85,20.1,0.2,0.5),
('Camarones','Cocidos',99,24,0.2,0.3),
('Huevo entero','Crudo',143,12.6,0.7,9.5),
('Clara de huevo','Cruda',52,10.9,0.7,0.2),
('Queso cottage','Natural',98,11.1,3.4,4.3),
('Queso ricota','Entera',174,11.3,3,13),
('Queso mozzarella','Entera',280,28,2.2,17),
('Yogur griego natural','Entero',97,9,3.9,5),
('Skyr natural','Descremado',63,11,4,0.2),
('Leche descremada','Líquida',34,3.4,5,0.1),
('Tofu firme','Natural',144,17.3,2.8,8.7),
('Tempeh','Natural',192,20.3,7.6,10.8),
('Seitán','Preparado',141,24.7,5,1.9),
('Lentejas','Cocidas',116,9,20.1,0.4),
('Garbanzos','Cocidos',164,8.9,27.4,2.6),
('Porotos negros','Cocidos',132,8.9,23.7,0.5),
('Edamame','Cocido',121,12,8.9,5.2),
('Proteína de suero (whey)','Polvo',400,80,8,6),
('Caseína','Polvo',370,80,5,3),
('Proteína de soja aislada','Polvo',335,88,2,1)
) as v(name, state, kcal, p, c, f)
on conflict do nothing;
