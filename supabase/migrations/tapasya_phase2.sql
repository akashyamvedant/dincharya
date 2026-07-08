-- ============================================================
-- TAPASYA (तपस्या) — Challenges & Group Practice
-- Phase 2: Circles / Groups
-- ============================================================

-- 1. Create circles table
CREATE TABLE IF NOT EXISTS public.tapasya_circles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  avatar_url TEXT,
  creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  max_members INT NOT NULL DEFAULT 50,
  invite_code TEXT UNIQUE DEFAULT substr(replace(gen_random_uuid()::text, '-', ''), 1, 8),
  is_public BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Create circle members table
CREATE TABLE IF NOT EXISTS public.tapasya_circle_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id UUID NOT NULL REFERENCES public.tapasya_circles(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (circle_id, user_id)
);

-- 3. Add foreign key constraint to tapasya_challenges linking it to tapasya_circles
ALTER TABLE public.tapasya_challenges
  ADD CONSTRAINT fk_tapasya_challenges_circle_id
  FOREIGN KEY (circle_id) REFERENCES public.tapasya_circles(id) ON DELETE SET NULL;

-- 4. Add index for circle_id in challenges
CREATE INDEX IF NOT EXISTS idx_challenges_circle_id ON public.tapasya_challenges(circle_id);

-- 5. Helper function for security checking without RLS recursion
CREATE OR REPLACE FUNCTION public.is_circle_member(circle_id UUID, user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.tapasya_circle_members m
    WHERE m.circle_id = $1
      AND m.user_id = $2
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Enable RLS for circles
ALTER TABLE public.tapasya_circles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read public circles" ON public.tapasya_circles
  FOR SELECT USING (is_public = true);

CREATE POLICY "Members and creators can read circles" ON public.tapasya_circles
  FOR SELECT USING (
    creator_id = auth.uid()
    OR public.is_circle_member(id, auth.uid())
  );

CREATE POLICY "Auth users can create circles" ON public.tapasya_circles
  FOR INSERT WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Creators can update their circles" ON public.tapasya_circles
  FOR UPDATE USING (auth.uid() = creator_id);

-- 7. Enable RLS for circle members
ALTER TABLE public.tapasya_circle_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read circle members" ON public.tapasya_circle_members
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.is_circle_member(circle_id, auth.uid())
    OR circle_id IN (
      SELECT id FROM public.tapasya_circles WHERE is_public = true
    )
  );

CREATE POLICY "Users can join public/invited circles" ON public.tapasya_circle_members
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can manage circle members" ON public.tapasya_circle_members
  FOR UPDATE USING (
    circle_id IN (
      SELECT id FROM public.tapasya_circles WHERE creator_id = auth.uid()
    )
    OR circle_id IN (
      SELECT circle_id FROM public.tapasya_circle_members WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Users can leave circles" ON public.tapasya_circle_members
  FOR DELETE USING (auth.uid() = user_id);
