-- Student dashboard logs which individual supplements were ticked
-- (logSupplements), but the column never existed in prod → PGRST204.
alter table public.supplement_logs add column if not exists ticked_items jsonb;
