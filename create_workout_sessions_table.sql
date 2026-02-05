-- Create workout_sessions table
CREATE TABLE IF NOT EXISTS workout_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    athlete_id UUID REFERENCES athletes(id) ON DELETE CASCADE,
    routine_id UUID REFERENCES routines(id) ON DELETE SET NULL,
    started_at TIMESTAMPTZ NOT NULL,
    duration_seconds INTEGER DEFAULT 0,
    sets_completed INTEGER DEFAULT 0,
    is_completed BOOLEAN DEFAULT false,
    set_logs JSONB DEFAULT '{}'::jsonb,
    reps_logs JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add comments for clarity
COMMENT ON COLUMN workout_sessions.set_logs IS 'Stores weight used: {exerciseIndex: {setIndex: weight}}';
COMMENT ON COLUMN workout_sessions.reps_logs IS 'Stores actual reps: {exerciseIndex: {setIndex: reps}}';

-- Enable Row Level Security (RLS)
ALTER TABLE workout_sessions ENABLE ROW LEVEL SECURITY;

-- Create policies (Adjust based on your actual auth requirements)
-- Allow students to insert their own sessions
CREATE POLICY "Enable insert for users based on athlete_id" ON workout_sessions
    FOR INSERT WITH CHECK (
        auth.uid() IN (
            SELECT user_id FROM athletes WHERE id = workout_sessions.athlete_id
        )
    );

-- Allow students to view their own sessions
CREATE POLICY "Enable select for users based on athlete_id" ON workout_sessions
    FOR SELECT USING (
        auth.uid() IN (
            SELECT user_id FROM athletes WHERE id = workout_sessions.athlete_id
        )
    );
