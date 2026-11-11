-- Migration: add_intake_form_schemas_table.sql
-- Creates the intake_form_schemas table so admin and trainers can maintain
-- their own versions of the athlete intake questionnaire.
-- Includes a SQL seed of the global default schema (kIntakeSections with
-- height_cm and weight_kg fields added in this sprint).

-- ============================================================
-- Table
-- ============================================================

create table if not exists public.intake_form_schemas (
  id          uuid primary key default gen_random_uuid(),
  owner_type  text not null check (owner_type in ('admin', 'trainer')),
  trainer_id  uuid references public.trainers(id) on delete cascade,
  sections    jsonb not null default '[]',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (owner_type, trainer_id)
);

comment on table public.intake_form_schemas is
  'Per-owner versions of the athlete intake questionnaire. One admin-global '
  'row (trainer_id IS NULL) and one row per trainer who customises the form.';

-- ============================================================
-- RLS
-- ============================================================

alter table public.intake_form_schemas enable row level security;

-- Admin: full access to global row + read all rows for oversight
create policy "admin_read_all_intake_schemas"
  on public.intake_form_schemas
  for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create policy "admin_write_global_intake_schema"
  on public.intake_form_schemas
  for all
  using (
    owner_type = 'admin' and
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  )
  with check (
    owner_type = 'admin' and
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- Trainer: read admin-global row (for seeding editor with defaults)
create policy "trainer_read_global_intake_schema"
  on public.intake_form_schemas
  for select
  using (
    owner_type = 'admin' and trainer_id is null and
    exists (
      select 1 from public.trainers
      where user_id = auth.uid()
    )
  );

-- Trainer: read + write own row
create policy "trainer_manage_own_intake_schema"
  on public.intake_form_schemas
  for all
  using (
    owner_type = 'trainer' and
    trainer_id in (
      select id from public.trainers where user_id = auth.uid()
    )
  )
  with check (
    owner_type = 'trainer' and
    trainer_id in (
      select id from public.trainers where user_id = auth.uid()
    )
  );

-- Student: read global row OR trainer's row for their assigned trainer
create policy "student_read_applicable_intake_schema"
  on public.intake_form_schemas
  for select
  using (
    -- Admin global row
    (owner_type = 'admin' and trainer_id is null)
    or
    -- Their trainer's override row
    (
      owner_type = 'trainer' and
      trainer_id in (
        select at.trainer_id
        from public.athletes at
        where at.user_id = auth.uid()
      )
    )
  );

-- ============================================================
-- Seed: global admin default schema (kIntakeSections as of 2026-11-10,
-- including the new height_cm and weight_kg fields)
-- ============================================================

insert into public.intake_form_schemas (owner_type, trainer_id, sections)
values (
  'admin',
  null,
  '[
    {
      "title": "Datos Personales",
      "subtitle": "Datos básicos del atleta.",
      "icon_name": "badge_outlined",
      "fields": [
        {
          "key": "full_name",
          "label": "Nombre y Apellido",
          "type": "text",
          "required": true,
          "options": [],
          "allow_other": false,
          "placeholder": "John Rodriguez",
          "allow_audio": false
        },
        {
          "key": "email",
          "label": "E-Mail",
          "type": "text",
          "required": true,
          "options": [],
          "allow_other": false,
          "placeholder": "correo@gmail.com",
          "allow_audio": false
        },
        {
          "key": "instagram",
          "label": "Instagram",
          "type": "text",
          "required": false,
          "options": [],
          "allow_other": false,
          "placeholder": "@usuario",
          "allow_audio": false
        },
        {
          "key": "age",
          "label": "Edad",
          "type": "number",
          "required": true,
          "options": [],
          "allow_other": false,
          "placeholder": "Ej. 25",
          "allow_audio": false
        },
        {
          "key": "height_cm",
          "label": "Altura (cm)",
          "type": "number",
          "required": true,
          "options": [],
          "allow_other": false,
          "placeholder": "Ej. 170",
          "allow_audio": false
        },
        {
          "key": "weight_kg",
          "label": "Peso actual (kg)",
          "type": "number",
          "required": true,
          "options": [],
          "allow_other": false,
          "placeholder": "Ej. 70",
          "allow_audio": false
        },
        {
          "key": "sexo",
          "label": "Sexo",
          "type": "singleChoice",
          "required": true,
          "options": ["Masculino", "Femenino"],
          "allow_other": true,
          "allow_audio": false
        },
        {
          "key": "initial_video_call",
          "label": "¿Estás dispuesto/a a realizar una Videollamada Inicial una vez entregada la planificación para charlar juntos tus objetivos?",
          "type": "singleChoice",
          "required": true,
          "options": ["Sí", "No"],
          "allow_other": true,
          "allow_audio": false
        }
      ]
    },
    {
      "title": "Entrenamiento",
      "subtitle": "Datos sobre tu entrenamiento.",
      "icon_name": "fitness_center",
      "fields": [
        {
          "key": "training_experience",
          "label": "¿Hace cuánto entrenas?",
          "type": "singleChoice",
          "required": true,
          "options": ["3 meses", "6 meses", "1 año", "2 años"],
          "allow_other": true,
          "allow_audio": false
        },
        {
          "key": "previous_routine",
          "label": "¿Qué rutina estabas haciendo hasta el momento?",
          "type": "longText",
          "required": false,
          "options": [],
          "allow_other": false,
          "allow_audio": false
        },
        {
          "key": "muscle_focus",
          "label": "¿Alguna preferencia de qué División Muscular preferís? ¿O a qué quisieras darle más enfoque?",
          "type": "longText",
          "required": false,
          "options": [],
          "allow_other": false,
          "helper": "Por ej. 2 días de piernas y 2 de tren superior.",
          "allow_audio": false
        },
        {
          "key": "gym",
          "label": "¿En qué gimnasio entrenas?",
          "type": "longText",
          "required": false,
          "options": [],
          "allow_other": false,
          "helper": "Nombre y, si podés, link de Instagram o web. Así vemos la disponibilidad de equipamiento y te armamos un plan más personalizado.",
          "allow_audio": false
        },
        {
          "key": "days_per_week",
          "label": "¿Cuántos días a la semana podés/querés ir a entrenar?",
          "type": "singleChoice",
          "required": true,
          "options": ["2 días", "3 días", "4 días", "5 días", "6 días"],
          "allow_other": false,
          "allow_audio": false
        },
        {
          "key": "objective",
          "label": "Objetivo",
          "type": "singleChoice",
          "required": true,
          "options": [
            "Volumen (ganancia de masa muscular)",
            "Definición (reducción de tejido adiposo)",
            "Recomposición (reducción de tejido adiposo y ganancia de masa muscular)"
          ],
          "allow_other": false,
          "allow_audio": false
        }
      ]
    },
    {
      "title": "Nutrición",
      "subtitle": "Datos sobre tu alimentación.",
      "icon_name": "restaurant",
      "fields": [
        {
          "key": "meals_per_day",
          "label": "¿Cuántas comidas al día solés hacer? ¿O cuántas quisieras tener?",
          "type": "text",
          "required": true,
          "options": [],
          "allow_other": false,
          "allow_audio": false
        },
        {
          "key": "intolerances",
          "label": "¿Sufrís alguna intolerancia?",
          "type": "multiChoice",
          "required": false,
          "options": ["Lactosa", "T.A.C.C."],
          "allow_other": true,
          "allow_audio": false
        },
        {
          "key": "foods_disliked",
          "label": "Comidas que NO te gustan o no querés tener en tu plan alimenticio",
          "type": "longText",
          "required": false,
          "options": [],
          "allow_other": false,
          "allow_audio": false
        },
        {
          "key": "foods_liked",
          "label": "Comidas que SÍ te gustaría tener en tu plan alimenticio",
          "type": "longText",
          "required": false,
          "options": [],
          "allow_other": false,
          "helper": "Comidas que disfrutás y te gustaría conservar en tu plan.",
          "allow_audio": false
        },
        {
          "key": "supplements",
          "label": "¿Consumís algún suplemento?",
          "type": "longText",
          "required": true,
          "options": [],
          "allow_other": false,
          "helper": "Por ej. Proteína en polvo, Creatina, BCAA, Glutamina...",
          "allow_audio": false
        },
        {
          "key": "medication",
          "label": "¿Consumís alguna medicación?",
          "type": "longText",
          "required": false,
          "options": [],
          "allow_other": false,
          "helper": "Por ej. Medicación para tiroides, pastilla anticonceptiva...",
          "allow_audio": false
        }
      ]
    },
    {
      "title": "Agenda / Horarios",
      "subtitle": "Para ayudarte con las comidas y el entrenamiento.",
      "icon_name": "schedule",
      "fields": [
        {
          "key": "schedule",
          "label": "Contame un poco sobre tu agenda y horarios diarios",
          "type": "longText",
          "required": true,
          "options": [],
          "allow_other": false,
          "helper": "¿A qué horario irías a entrenar? ¿A qué hora solés desayunar/almorzar/cenar? ¿Tenés tiempo para cocinarte? Horarios laborales. Podés escribir o grabar una nota de voz.",
          "allow_audio": true
        }
      ]
    },
    {
      "title": "Objetivos",
      "subtitle": "Objetivos a corto, mediano y largo plazo.",
      "icon_name": "flag",
      "fields": [
        {
          "key": "goal_short_term",
          "label": "Objetivo a CORTO plazo (1 mes)",
          "type": "longText",
          "required": false,
          "options": [],
          "allow_other": false,
          "allow_audio": false
        },
        {
          "key": "goal_mid_term",
          "label": "Objetivo a MEDIANO plazo (3 meses)",
          "type": "longText",
          "required": false,
          "options": [],
          "allow_other": false,
          "allow_audio": false
        },
        {
          "key": "goal_long_term",
          "label": "Objetivo a LARGO plazo (12 meses)",
          "type": "longText",
          "required": false,
          "options": [],
          "allow_other": false,
          "allow_audio": false
        }
      ]
    }
  ]'::jsonb
)
on conflict (owner_type, trainer_id) do nothing;
