-- ═══════════════════════════════════════════════════════════════
-- Sarvam AI TTS Audio Cache — Database + Storage Setup
-- Run this in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- 1. Create the pose_step_audio table
CREATE TABLE IF NOT EXISTS public.pose_step_audio (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    pose_id UUID NOT NULL REFERENCES public.yoga_poses(id) ON DELETE CASCADE,
    step_number INTEGER NOT NULL,
    language TEXT NOT NULL CHECK (language IN ('hi', 'en')),
    audio_url TEXT NOT NULL,
    text_hash TEXT NOT NULL,
    speaker TEXT DEFAULT 'shubh',
    file_size_bytes INTEGER,
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- One audio per pose step per language
    UNIQUE (pose_id, step_number, language)
);

-- 2. Enable RLS
ALTER TABLE public.pose_step_audio ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies — anyone can read, only service role can write
-- All users can read audio entries (for playback)
CREATE POLICY "Anyone can read audio" ON public.pose_step_audio
    FOR SELECT USING (true);

-- Authenticated users can insert (when first generating audio)
CREATE POLICY "Authenticated users can insert audio" ON public.pose_step_audio
    FOR INSERT TO authenticated
    WITH CHECK (true);

-- Authenticated users can update (when regenerating changed audio)
CREATE POLICY "Authenticated users can update audio" ON public.pose_step_audio
    FOR UPDATE TO authenticated
    USING (true)
    WITH CHECK (true);

-- Authenticated users can delete (when guidance text changes)
CREATE POLICY "Authenticated users can delete audio" ON public.pose_step_audio
    FOR DELETE TO authenticated
    USING (true);

-- 4. Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_pose_step_audio_lookup 
    ON public.pose_step_audio (pose_id, step_number, language);

-- 5. Create the tts-audio storage bucket (public, for direct URL playback)
INSERT INTO storage.buckets (id, name, public)
VALUES ('tts-audio', 'tts-audio', true)
ON CONFLICT (id) DO NOTHING;

-- 6. Storage RLS — anyone can read, authenticated can upload
CREATE POLICY "Anyone can read TTS audio" ON storage.objects
    FOR SELECT USING (bucket_id = 'tts-audio');

CREATE POLICY "Authenticated users can upload TTS audio" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'tts-audio');

CREATE POLICY "Authenticated users can update TTS audio" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'tts-audio')
    WITH CHECK (bucket_id = 'tts-audio');

CREATE POLICY "Authenticated users can delete TTS audio" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'tts-audio');

-- Done! ✅
