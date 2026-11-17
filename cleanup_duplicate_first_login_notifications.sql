-- 2026-11-17: the client (SupabaseService.recordFirstLogin) inserted 'firstLogin'
-- notifications on top of the ones the on_first_login trigger already creates
-- ('first_login' for admins, 'new_student' for the trainer), and could run ~3x per
-- login. Client inserts removed; this deletes the client duplicates (65 rows applied).
delete from notifications c
where c.type = 'firstLogin'
  and exists (
    select 1 from notifications t
    where t.user_id = c.user_id
      and t.type in ('first_login', 'new_student')
      and abs(extract(epoch from t.created_at - c.created_at)) < 120
  );
