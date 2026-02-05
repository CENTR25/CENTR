-- Add reps_logs column to workout_sessions table
ALTER TABLE workout_sessions 
ADD COLUMN IF NOT EXISTS reps_logs JSONB;

COMMENT ON COLUMN workout_sessions.reps_logs IS 'Stores the actual reps performed for each set: {exerciseIndex: {setIndex: reps}}';
