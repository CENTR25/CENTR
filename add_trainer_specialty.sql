-- Admin create/edit trainer UI collects a specialty, but the column never
-- existed in prod, so createTrainer/updateTrainer crashed with PGRST204.
alter table public.trainers add column if not exists specialty text;
