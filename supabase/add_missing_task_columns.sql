-- ============================================
-- MIGRATION: Add ALL missing columns
-- Run this in Supabase SQL Editor
-- ============================================

-- ============================================
-- 1. LOCAL_TASKS: task lifecycle columns
-- ============================================
ALTER TABLE public.local_tasks ADD COLUMN IF NOT EXISTS type TEXT;
ALTER TABLE public.local_tasks ADD COLUMN IF NOT EXISTS duration TEXT;
ALTER TABLE public.local_tasks ADD COLUMN IF NOT EXISTS duration_minutes INTEGER;
ALTER TABLE public.local_tasks ADD COLUMN IF NOT EXISTS icon TEXT;
ALTER TABLE public.local_tasks ADD COLUMN IF NOT EXISTS is_inevitable BOOLEAN DEFAULT FALSE;
ALTER TABLE public.local_tasks ADD COLUMN IF NOT EXISTS profile_source TEXT DEFAULT 'custom';
ALTER TABLE public.local_tasks ADD COLUMN IF NOT EXISTS task_status TEXT DEFAULT 'pending';
ALTER TABLE public.local_tasks ADD COLUMN IF NOT EXISTS status_updated_at TIMESTAMPTZ;
ALTER TABLE public.local_tasks ADD COLUMN IF NOT EXISTS deadline_time TEXT;

-- ============================================
-- 2. ROUTINE_TRACKING: feedback & analytics columns
-- ============================================
ALTER TABLE public.routine_tracking ADD COLUMN IF NOT EXISTS task_id UUID;
ALTER TABLE public.routine_tracking ADD COLUMN IF NOT EXISTS scheduled_time TEXT;
ALTER TABLE public.routine_tracking ADD COLUMN IF NOT EXISTS actual_time TEXT;
ALTER TABLE public.routine_tracking ADD COLUMN IF NOT EXISTS actual_duration_minutes INTEGER;
ALTER TABLE public.routine_tracking ADD COLUMN IF NOT EXISTS completion_percent INTEGER DEFAULT 100;
ALTER TABLE public.routine_tracking ADD COLUMN IF NOT EXISTS difficulty_rating INTEGER;
ALTER TABLE public.routine_tracking ADD COLUMN IF NOT EXISTS quality_rating INTEGER;
ALTER TABLE public.routine_tracking ADD COLUMN IF NOT EXISTS skip_reason TEXT;
ALTER TABLE public.routine_tracking ADD COLUMN IF NOT EXISTS xp_earned INTEGER DEFAULT 0;
ALTER TABLE public.routine_tracking ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'completed';
ALTER TABLE public.routine_tracking ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ============================================
-- 3. UNIQUE CONSTRAINT for upsert support
-- ============================================
-- This allows the feedback dialog to upsert (update if exists, insert if not)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'routine_tracking_user_task_date_unique'
  ) THEN
    ALTER TABLE public.routine_tracking 
      ADD CONSTRAINT routine_tracking_user_task_date_unique 
      UNIQUE (user_id, task_id, tracking_date);
  END IF;
END $$;

-- ============================================
-- 4. INDEX for faster queries
-- ============================================
CREATE INDEX IF NOT EXISTS idx_local_tasks_task_status ON public.local_tasks(task_status);
CREATE INDEX IF NOT EXISTS idx_routine_tracking_task_id ON public.routine_tracking(task_id);
