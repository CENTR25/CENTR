-- Allow trainers to read check-ins of their own students (and admins to read all).
-- check_ins.user_id references the student's profile/auth id, so we map through
-- athletes.user_id. Without this policy the trainer's "Fotos Check-in" section
-- can never show data.

create policy "check_ins_trainer_read" on public.check_ins
  for select
  to authenticated
  using (
    user_id in (
      select a.user_id
      from public.athletes a
      where a.trainer_id = (select private.my_trainer_id())
    )
    or (select private.get_role()) = 'admin'
  );
