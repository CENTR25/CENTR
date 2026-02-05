-- Add day_number column to workout_sessions table
ALTER TABLE workout_sessions 
ADD COLUMN IF NOT EXISTS day_number INTEGER;

COMMENT ON COLUMN workout_sessions.day_number IS 'The day number of the routine that this session corresponds to (e.g., 1 for Monday/Day 1)';
