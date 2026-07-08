-- ============================================================
-- TAPASYA (तपस्या) — Challenges & Group Practice
-- Phase 1: Core Tables for Challenges System
-- ============================================================

-- 1. Challenges — Main challenge definitions
CREATE TABLE IF NOT EXISTS tapasya_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  circle_id UUID, -- null = 1v1 or community (FK added in Phase 2)
  challenge_type TEXT NOT NULL CHECK (challenge_type IN ('1v1', 'group', 'community')),
  category TEXT NOT NULL CHECK (category IN ('yoga', 'pranayama', 'meditation', 'any')),
  specific_session_id UUID, -- null = any session in category
  goal_type TEXT NOT NULL CHECK (goal_type IN ('total_minutes', 'session_count', 'streak_days')),
  goal_value INT NOT NULL DEFAULT 60, -- target value
  duration_days INT NOT NULL DEFAULT 7,
  starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ends_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'completed', 'cancelled')),
  is_public BOOLEAN NOT NULL DEFAULT false,
  max_participants INT NOT NULL DEFAULT 20,
  invite_code TEXT UNIQUE DEFAULT substr(replace(gen_random_uuid()::text, '-', ''), 1, 8),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Challenge Participants — Who's in which challenge
CREATE TABLE IF NOT EXISTS tapasya_challenge_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID NOT NULL REFERENCES tapasya_challenges(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'accepted' CHECK (status IN ('invited', 'accepted', 'declined')),
  current_progress INT NOT NULL DEFAULT 0,
  rank INT,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (challenge_id, user_id)
);

-- 3. Challenge Progress — Daily progress snapshots
CREATE TABLE IF NOT EXISTS tapasya_challenge_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_id UUID NOT NULL REFERENCES tapasya_challenge_participants(id) ON DELETE CASCADE,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  value INT NOT NULL DEFAULT 0, -- minutes or count for this day
  sessions_detail JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (participant_id, date)
);

-- 4. Badge Definitions — Seeded by admin
CREATE TABLE IF NOT EXISTS tapasya_badges (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL, -- Hindi name
  title_en TEXT NOT NULL, -- English name
  description TEXT NOT NULL,
  icon TEXT NOT NULL, -- emoji
  category TEXT NOT NULL CHECK (category IN ('challenge', 'social', 'streak', 'milestone')),
  condition_type TEXT NOT NULL, -- 'challenge_wins', 'streak', 'sessions', etc.
  condition_value INT NOT NULL DEFAULT 1, -- how many to earn
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. User Badges — Earned achievements
CREATE TABLE IF NOT EXISTS tapasya_user_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  badge_id TEXT NOT NULL REFERENCES tapasya_badges(id) ON DELETE CASCADE,
  earned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  challenge_id UUID REFERENCES tapasya_challenges(id) ON DELETE SET NULL,
  UNIQUE (user_id, badge_id)
);

-- 6. Activity Feed — Social activity log
CREATE TABLE IF NOT EXISTS tapasya_activity_feed (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  circle_id UUID, -- null = global/personal feed
  action_type TEXT NOT NULL CHECK (action_type IN (
    'challenge_created', 'challenge_joined', 'challenge_won',
    'practice_completed', 'badge_earned', 'streak_milestone',
    'encouragement'
  )),
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. Reactions on activity feed
CREATE TABLE IF NOT EXISTS tapasya_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id UUID NOT NULL REFERENCES tapasya_activity_feed(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL CHECK (emoji IN ('🙏', '👏', '🔥', '💪', '⭐')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (activity_id, user_id)
);

-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX idx_challenges_status ON tapasya_challenges(status);
CREATE INDEX idx_challenges_creator ON tapasya_challenges(creator_id);
CREATE INDEX idx_challenges_type ON tapasya_challenges(challenge_type);
CREATE INDEX idx_challenges_public ON tapasya_challenges(is_public) WHERE is_public = true;
CREATE INDEX idx_participants_challenge ON tapasya_challenge_participants(challenge_id);
CREATE INDEX idx_participants_user ON tapasya_challenge_participants(user_id);
CREATE INDEX idx_progress_participant ON tapasya_challenge_progress(participant_id);
CREATE INDEX idx_progress_date ON tapasya_challenge_progress(date);
CREATE INDEX idx_activity_user ON tapasya_activity_feed(user_id);
CREATE INDEX idx_activity_created ON tapasya_activity_feed(created_at DESC);
CREATE INDEX idx_user_badges_user ON tapasya_user_badges(user_id);
CREATE INDEX idx_reactions_activity ON tapasya_reactions(activity_id);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Challenges: anyone can read public/community, participants can read their own
ALTER TABLE tapasya_challenges ENABLE ROW LEVEL SECURITY;

-- 1. Create helper function with SECURITY DEFINER to bypass RLS recursion
CREATE OR REPLACE FUNCTION public.is_challenge_participant(challenge_id UUID, user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.tapasya_challenge_participants p
    WHERE p.challenge_id = $1
      AND p.user_id = $2
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE POLICY "Anyone can read public challenges" ON tapasya_challenges
  FOR SELECT USING (is_public = true OR challenge_type = 'community');

CREATE POLICY "Participants and creators can read challenges" ON tapasya_challenges
  FOR SELECT USING (
    creator_id = auth.uid()
    OR public.is_challenge_participant(id, auth.uid())
  );

CREATE POLICY "Auth users can create challenges" ON tapasya_challenges
  FOR INSERT WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Creators can update their challenges" ON tapasya_challenges
  FOR UPDATE USING (auth.uid() = creator_id);

-- Participants: read own, insert self
ALTER TABLE tapasya_challenge_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read challenge participants" ON tapasya_challenge_participants
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.is_challenge_participant(challenge_id, auth.uid())
    OR challenge_id IN (
      SELECT id FROM public.tapasya_challenges 
      WHERE is_public = true OR challenge_type = 'community'
    )
  );

CREATE POLICY "Users can join challenges" ON tapasya_challenge_participants
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own progress" ON tapasya_challenge_participants
  FOR UPDATE USING (auth.uid() = user_id);

-- Progress: users manage their own
ALTER TABLE tapasya_challenge_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read progress of their challenges" ON tapasya_challenge_progress
  FOR SELECT USING (
    participant_id IN (
      SELECT id FROM tapasya_challenge_participants
      WHERE challenge_id IN (
        SELECT challenge_id FROM tapasya_challenge_participants WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can insert own progress" ON tapasya_challenge_progress
  FOR INSERT WITH CHECK (
    participant_id IN (
      SELECT id FROM tapasya_challenge_participants WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own progress" ON tapasya_challenge_progress
  FOR UPDATE USING (
    participant_id IN (
      SELECT id FROM tapasya_challenge_participants WHERE user_id = auth.uid()
    )
  );

-- Badges: read-only for everyone
ALTER TABLE tapasya_badges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read badges" ON tapasya_badges FOR SELECT USING (true);

-- User Badges: users read own
ALTER TABLE tapasya_user_badges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own badges" ON tapasya_user_badges
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "System can insert badges" ON tapasya_user_badges
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Activity Feed: public read
ALTER TABLE tapasya_activity_feed ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read activity feed" ON tapasya_activity_feed
  FOR SELECT USING (true);
CREATE POLICY "Users can insert own activity" ON tapasya_activity_feed
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Reactions: public read, users insert own
ALTER TABLE tapasya_reactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read reactions" ON tapasya_reactions FOR SELECT USING (true);
CREATE POLICY "Users can add reactions" ON tapasya_reactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can remove own reactions" ON tapasya_reactions
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- SEED: Badge Definitions
-- ============================================================
INSERT INTO tapasya_badges (id, title, title_en, description, icon, category, condition_type, condition_value) VALUES
  ('first_win',       'विजयी',      'First Win',        'Win your first challenge',                    '🏆', 'challenge',  'challenge_wins',   1),
  ('win_streak_3',    'त्रिविजय',    '3-Win Streak',     'Win 3 challenges in a row',                   '🔥', 'challenge',  'win_streak',       3),
  ('win_streak_5',    'अपराजित',     'Unbeatable',       'Win 5 challenges in a row',                   '⚡', 'challenge',  'win_streak',       5),
  ('challenger_10',   'प्रेरक',      'Challenger',       'Create 10 challenges',                        '📣', 'social',     'challenges_created', 10),
  ('joiner_20',       'संघ तारा',    'Community Star',   'Join 20 challenges',                          '⭐', 'social',     'challenges_joined', 20),
  ('perfect_7',       'सप्ताह सिद्ध', 'Perfect Week',    'Complete every day of a 7-day challenge',     '💎', 'streak',     'perfect_challenge', 7),
  ('perfect_30',      'अखंड',       'Unbroken',         'Complete every day of a 30-day challenge',     '🕉️', 'streak',     'perfect_challenge', 30),
  ('sessions_50',     'अभ्यासी',     'Practitioner',     'Complete 50 guided sessions',                 '🧘', 'milestone',  'total_sessions',   50),
  ('sessions_100',    'साधक',       'Seeker',           'Complete 100 guided sessions',                '🙏', 'milestone',  'total_sessions',   100),
  ('minutes_1000',    'तपस्वी',      'Tapasvi',          'Practice 1000 total minutes',                 '🔱', 'milestone',  'total_minutes',    1000)
ON CONFLICT (id) DO NOTHING;
