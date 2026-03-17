-- =====================================================
-- Dincharya Admin Dashboard: Media Upload Setup
-- Run this SQL in Supabase Dashboard → SQL Editor
-- =====================================================

-- 1. Add image columns to yoga_poses table
ALTER TABLE yoga_poses ADD COLUMN IF NOT EXISTS cover_image_url TEXT;
ALTER TABLE yoga_poses ADD COLUMN IF NOT EXISTS literature_image_url TEXT;

-- 2. Create storage bucket for session media (if not exists)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'session-media',
  'session-media',
  true,
  209715200,  -- 200MB max file size
  ARRAY[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml',
    'video/mp4', 'video/webm', 'video/quicktime',
    'audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/mp4', 'audio/aac',
    'application/json'  -- for Lottie animations
  ]
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 209715200;

-- 3. RLS Policies for session-media bucket
-- Drop existing policies first (safe to re-run)
DROP POLICY IF EXISTS "Public read access for session-media" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload to session-media" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated update in session-media" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated delete from session-media" ON storage.objects;

-- Allow anyone to read (public bucket)
CREATE POLICY "Public read access for session-media"
ON storage.objects FOR SELECT
USING (bucket_id = 'session-media');

-- Allow authenticated users to upload
CREATE POLICY "Authenticated upload to session-media"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'session-media');

-- Allow authenticated users to update their uploads
CREATE POLICY "Authenticated update in session-media"
ON storage.objects FOR UPDATE
USING (bucket_id = 'session-media');

-- Allow authenticated users to delete
CREATE POLICY "Authenticated delete from session-media"
ON storage.objects FOR DELETE
USING (bucket_id = 'session-media');

-- =====================================================
-- Done! The admin dashboard can now upload files to
-- the session-media bucket.
-- Folders used:
--   poses/covers/    - Yoga pose cover images
--   poses/literature/ - Literature book illustrations 
--   poses/           - Individual step pose images
--   animations/      - Lottie animation files
--   sessions/        - Primary session media
--   audio/           - Audio files
--   video/           - Video files
--   thumbnails/      - Session thumbnails
--   avatars/         - Instructor avatars
-- =====================================================
