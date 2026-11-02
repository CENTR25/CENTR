-- Store the specific weekdays a routine is trained on (1=Mon … 7=Sun),
-- replacing the implicit "first N consecutive days" semantics of days_per_week.
-- Empty array = fall back to [1..days_per_week] in-app for legacy routines.
alter table routines add column if not exists week_days integer[] default '{}'::integer[];
