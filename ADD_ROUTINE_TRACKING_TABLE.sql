-- ============================================
-- ADD ROUTINE_TRACKING TABLE (if not exists from V2)
-- ============================================

-- This script adds routine tracking table to Supabase
-- Run this in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS public.routine_tracking (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_name TEXT NOT NULL,
  completed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  scheduled_time TEXT,
  reason TEXT,
  notes TEXT,
  tracking_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_routine_tracking_user_id ON public.routine_tracking(user_id);
CREATE INDEX IF NOT EXISTS idx_routine_tracking_date ON public.routine_tracking(tracking_date);
CREATE INDEX IF NOT EXISTS idx_routine_tracking_user_date ON public.routine_tracking(user_id, tracking_date);

-- Enable RLS
ALTER TABLE public.routine_tracking ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view own tracking" ON public.routine_tracking;
DROP POLICY IF EXISTS "Users can insert own tracking" ON public.routine_tracking;
DROP POLICY IF EXISTS "Users can update own tracking" ON public.routine_tracking;
DROP POLICY IF EXISTS "Users can delete own tracking" ON public.routine_tracking;

CREATE POLICY "Users can view own tracking"
    ON public.routine_tracking FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own tracking"
    ON public.routine_tracking FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own tracking"
    ON public.routine_tracking FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own tracking"
    ON public.routine_tracking FOR DELETE
    USING (auth.uid() = user_id);

-- Updated at trigger
DROP TRIGGER IF EXISTS set_routine_tracking_updated_at ON public.routine_tracking;

CREATE TRIGGER set_routine_tracking_updated_at
    BEFORE UPDATE ON public.routine_tracking
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- Verification
SELECT COUNT(*) as table_exists FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name = 'routine_tracking';
