-- News articles shown as dashboard cards (admin-managed).
-- Code (news_service.dart / news_model.dart) was written against this table
-- but it never existed in prod — news CRUD failed silently.
create table if not exists public.news_articles (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text not null,
  image_url text,
  accent_color text not null default '#9C27B0',
  icon_name text not null default 'newspaper',
  is_published boolean not null default true,
  display_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

alter table public.news_articles enable row level security;

-- Any authenticated user reads published news; admin reads all.
create policy "news_articles_select" on public.news_articles
  for select to authenticated
  using (is_published = true or (select private.get_role()) = 'admin');

-- Only admin writes.
create policy "news_articles_admin_insert" on public.news_articles
  for insert to authenticated
  with check ((select private.get_role()) = 'admin');

create policy "news_articles_admin_update" on public.news_articles
  for update to authenticated
  using ((select private.get_role()) = 'admin')
  with check ((select private.get_role()) = 'admin');

create policy "news_articles_admin_delete" on public.news_articles
  for delete to authenticated
  using ((select private.get_role()) = 'admin');
