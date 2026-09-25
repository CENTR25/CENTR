-- Track when a student acknowledges their trainer's "Lectura Obligatoria".
-- Once set, the home banner is hidden; the reading stays reachable from the menu.
alter table athletes
  add column if not exists required_reading_accepted_at timestamptz;
