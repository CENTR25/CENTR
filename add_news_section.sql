-- 2026-11-17 (Alan QA Nov #3): admin picks a section per news article
-- (Noticias / Marcas / Funciones / Eventos). Existing rows default to 'noticias'.
alter table public.news_articles
  add column if not exists section text not null default 'noticias';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'news_articles_section_check'
  ) then
    alter table public.news_articles
      add constraint news_articles_section_check
      check (section in ('noticias', 'marcas', 'funciones', 'eventos'));
  end if;
end $$;
