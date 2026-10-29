-- create_help_articles.sql
-- FAQ / help-center content shown in the trainer "Ayuda" screen. Managed by
-- admins (CRUD in the admin dashboard); read by any authenticated user.
--
-- category slug matches the trainer Ayuda filter chips:
--   'alumnos' | 'planes' | 'pagos'  (the "Todo" chip shows all)

create table if not exists public.help_articles (
  id uuid primary key default gen_random_uuid(),
  category text,                                   -- 'alumnos' | 'planes' | 'pagos' | null
  question text not null,
  answer text not null,
  order_index int not null default 0,
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.help_articles enable row level security;

-- Any authenticated user can read published articles.
drop policy if exists "help_articles_read_published" on public.help_articles;
create policy "help_articles_read_published"
  on public.help_articles for select
  to authenticated
  using (is_published = true);

-- Admins manage everything (profiles.role = 'admin').
drop policy if exists "help_articles_admin_all" on public.help_articles;
create policy "help_articles_admin_all"
  on public.help_articles for all
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );

-- ── Seed the four Figma FAQs (only if the table is empty) ───────────────────
insert into public.help_articles (category, question, answer, order_index)
select * from (values
  ('alumnos',
   '¿Cómo invito a un alumno?',
   'Desde Alumnos tocá "+" y compartí el link de invitación. Cuando se registra aparece en tu lista.',
   0),
  ('planes',
   '¿Qué pasa si llego al límite de alumnos?',
   'Al alcanzar el máximo de tu plan no podés sumar nuevos alumnos. Mejorá tu plan desde Mi suscripción para ampliar el cupo.',
   1),
  ('planes',
   '¿Cómo edito un plan solo para un alumno?',
   'Abrí el alumno, entrá a su rutina o plan de comidas y tocá editar. Los cambios se guardan como una versión personalizada sólo para ese alumno.',
   2),
  ('pagos',
   '¿Cómo cambio el método de pago?',
   'Entrá a Mi suscripción y tocá "Cambiar" junto al método de pago para actualizar tus datos de cobro.',
   3)
) as seed(category, question, answer, order_index)
where not exists (select 1 from public.help_articles);
