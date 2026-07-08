-- ============================================================
-- TAPASYA (तपस्या) — Challenges & Group Practice
-- Phase 3: Live Group Sessions
-- ============================================================

-- 1. Create live practice rooms table
CREATE TABLE IF NOT EXISTS public.tapasya_live_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id UUID NOT NULL REFERENCES public.tapasya_circles(id) ON DELETE CASCADE,
  session_id UUID REFERENCES public.sessions(id) ON DELETE SET NULL, -- null = self-paced/custom timer
  host_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('yoga', 'pranayama', 'meditation', 'any')),
  duration_seconds INT NOT NULL DEFAULT 600,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed')),
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  paused_at TIMESTAMPTZ,
  remaining_seconds INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Create live participants table
CREATE TABLE IF NOT EXISTS public.tapasya_live_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.tapasya_live_rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_ping TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (room_id, user_id)
);

-- 3. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_live_rooms_circle ON public.tapasya_live_rooms(circle_id);
CREATE INDEX IF NOT EXISTS idx_live_participants_room ON public.tapasya_live_participants(room_id);

-- 4. Enable RLS
ALTER TABLE public.tapasya_live_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tapasya_live_participants ENABLE ROW LEVEL SECURITY;

-- 5. RLS policies for live rooms using circle member check
CREATE POLICY "Circle members can read live rooms" ON public.tapasya_live_rooms
  FOR SELECT USING (
    public.is_circle_member(circle_id, auth.uid())
    OR host_id = auth.uid()
  );

CREATE POLICY "Circle members can start live rooms" ON public.tapasya_live_rooms
  FOR INSERT WITH CHECK (
    public.is_circle_member(circle_id, auth.uid())
    AND host_id = auth.uid()
  );

CREATE POLICY "Hosts can update room status" ON public.tapasya_live_rooms
  FOR UPDATE USING (host_id = auth.uid());

CREATE POLICY "Hosts can delete rooms" ON public.tapasya_live_rooms
  FOR DELETE USING (host_id = auth.uid());

-- 6. RLS policies for live participants
CREATE POLICY "Circle members can read live participants" ON public.tapasya_live_participants
  FOR SELECT USING (
    room_id IN (
      SELECT id FROM public.tapasya_live_rooms 
      WHERE public.is_circle_member(circle_id, auth.uid())
    )
  );

CREATE POLICY "Users can join live rooms" ON public.tapasya_live_participants
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their ping" ON public.tapasya_live_participants
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can leave rooms" ON public.tapasya_live_participants
  FOR DELETE USING (auth.uid() = user_id);
