-- ============================================
-- Phase 2: Personalization Schema Migration
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. Add dosha and goals columns to user_profiles
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS dominant_dosha TEXT,
  ADD COLUMN IF NOT EXISTS primary_goals TEXT[] DEFAULT '{}';

-- Valid dosha constraint
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'user_profiles_dominant_dosha_check'
  ) THEN
    ALTER TABLE public.user_profiles
      ADD CONSTRAINT user_profiles_dominant_dosha_check
      CHECK (dominant_dosha IS NULL OR dominant_dosha IN ('vata', 'pitta', 'kapha'));
  END IF;
END $$;

-- 2. Programs table
CREATE TABLE IF NOT EXISTS public.programs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  title_hindi TEXT,
  description TEXT,
  category TEXT NOT NULL CHECK (category IN ('meditation', 'pranayama', 'yoga', 'mixed')),
  difficulty INTEGER DEFAULT 3 CHECK (difficulty >= 1 AND difficulty <= 5),
  total_sessions INTEGER DEFAULT 0,
  duration_days INTEGER DEFAULT 7,
  dosha_affinity TEXT[] DEFAULT '{}',
  thumbnail_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Program sessions (junction table)
CREATE TABLE IF NOT EXISTS public.program_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id UUID NOT NULL REFERENCES public.programs(id) ON DELETE CASCADE,
  session_id UUID NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
  sequence_order INTEGER NOT NULL DEFAULT 0,
  day_number INTEGER NOT NULL DEFAULT 1,
  UNIQUE(program_id, sequence_order)
);

-- 4. User enrollments
CREATE TABLE IF NOT EXISTS public.user_program_enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  program_id UUID NOT NULL REFERENCES public.programs(id) ON DELETE CASCADE,
  current_session_index INTEGER DEFAULT 0,
  completed BOOLEAN DEFAULT false,
  enrolled_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ,
  UNIQUE(user_id, program_id)
);

-- 5. RLS
ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.program_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_program_enrollments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active programs"
  ON public.programs FOR SELECT USING (is_active = true);

CREATE POLICY "Anyone can read program sessions"
  ON public.program_sessions FOR SELECT USING (true);

CREATE POLICY "Users can view own enrollments"
  ON public.user_program_enrollments FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can enroll in programs"
  ON public.user_program_enrollments FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own enrollments"
  ON public.user_program_enrollments FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own enrollments"
  ON public.user_program_enrollments FOR DELETE USING (auth.uid() = user_id);

-- 6. Seed sample programs
INSERT INTO public.programs (title, title_hindi, description, category, difficulty, total_sessions, duration_days, dosha_affinity) VALUES
  ('7-Day Calm Mind', 'शांत मन - 7 दिन', 'A week-long journey to inner peace through daily meditation.', 'meditation', 2, 7, 7, ARRAY['vata', 'pitta']),
  ('Beginner Pranayama', 'प्राणायाम शुरुआत', 'Learn foundational breathing techniques from basics to advanced.', 'pranayama', 1, 5, 5, ARRAY['vata', 'kapha']),
  ('Morning Yoga Flow', 'सुबह का योग', 'Energize your mornings with progressive yoga sequences.', 'yoga', 3, 7, 7, ARRAY['kapha', 'pitta']),
  ('Stress Relief Journey', 'तनाव मुक्ति', 'Comprehensive stress relief combining meditation, breathing, and yoga.', 'mixed', 2, 10, 14, ARRAY['vata', 'pitta', 'kapha']),
  ('Deep Sleep Program', 'गहरी नींद', 'Train your mind for restful, deep sleep with evening practices.', 'meditation', 1, 7, 7, ARRAY['vata'])
ON CONFLICT DO NOTHING;
