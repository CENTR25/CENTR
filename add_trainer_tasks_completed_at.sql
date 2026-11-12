-- Real completion date for trainer tasks ("Ver completados" shows both the
-- due date and when the task was actually marked done).
-- Set server-side by trigger so every client path (toggle, edit) is covered.
-- Existing done tasks have no known completion date and stay NULL.

alter table public.trainer_tasks
  add column if not exists completed_at timestamptz;

create or replace function private.set_trainer_task_completed_at()
returns trigger language plpgsql set search_path to ''
as $$
begin
  if new.is_done and (tg_op = 'INSERT' or not coalesce(old.is_done, false)) then
    new.completed_at := now();
  elsif not new.is_done then
    new.completed_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trainer_tasks_completed_at on public.trainer_tasks;
create trigger trainer_tasks_completed_at
  before insert or update of is_done on public.trainer_tasks
  for each row execute function private.set_trainer_task_completed_at();
