-- Affiliated brands shown in the student "Beneficios" tab (admin-managed).
-- Replaces the previously hardcoded benefit cards with data the admin edits himself.
create table if not exists public.affiliated_brands (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  discount_code text,
  banner_text text,
  website_url text,
  instagram_url text,
  logo_url text,
  is_active boolean not null default true,
  display_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

alter table public.affiliated_brands enable row level security;

-- Any authenticated user reads active brands; admin reads all.
create policy "affiliated_brands_select" on public.affiliated_brands
  for select to authenticated
  using (is_active = true or (select private.get_role()) = 'admin');

-- Only admin writes.
create policy "affiliated_brands_admin_insert" on public.affiliated_brands
  for insert to authenticated
  with check ((select private.get_role()) = 'admin');

create policy "affiliated_brands_admin_update" on public.affiliated_brands
  for update to authenticated
  using ((select private.get_role()) = 'admin')
  with check ((select private.get_role()) = 'admin');

create policy "affiliated_brands_admin_delete" on public.affiliated_brands
  for delete to authenticated
  using ((select private.get_role()) = 'admin');
