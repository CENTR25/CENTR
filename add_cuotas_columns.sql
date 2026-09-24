-- Migration: add_cuotas_columns
-- Adds last_fee_notified_at to athletes so the client-side renewal-check can
-- stamp today's date and skip re-notifying if the trainer reopens the app.
-- athletes.next_renewal_date already exists (no new column needed for that).

ALTER TABLE athletes ADD COLUMN IF NOT EXISTS last_fee_notified_at date;
