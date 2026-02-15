-- ============================================
-- DINCHARYA - COMPLETE DATABASE SETUP v5.0
-- ============================================
-- Run each section separately if needed
-- ============================================

-- ENABLE UUID EXTENSION (Run this first if not enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- TABLE 1: USER PROFILES
-- ============================================
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  bio TEXT DEFAULT '',
  avatar_url TEXT,
  phone TEXT,
  lifestyle_profile TEXT DEFAULT 'custom',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- TABLE 2: SUBSCRIPTIONS
-- ============================================
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id TEXT NOT NULL,
  plan_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  razorpay_payment_id TEXT,
  razorpay_order_id TEXT UNIQUE,
  razorpay_signature TEXT,
  amount INTEGER NOT NULL,
  currency TEXT DEFAULT 'INR',
  started_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- TABLE 3: ADMIN ROLES
-- ============================================
CREATE TABLE IF NOT EXISTS public.admin_roles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'admin',
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  granted_by UUID REFERENCES auth.users(id)
);

-- ============================================
-- TABLE 4: ROUTINE TRACKING
-- ============================================
CREATE TABLE IF NOT EXISTS public.routine_tracking (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_name TEXT NOT NULL,
  completed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  reason TEXT,
  notes TEXT,
  tracking_date DATE NOT NULL,
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- TABLE 5: PAYMENT AUDIT LOG
-- ============================================
CREATE TABLE IF NOT EXISTS public.payment_audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  razorpay_payment_id TEXT,
  razorpay_order_id TEXT,
  amount INTEGER,
  currency TEXT DEFAULT 'INR',
  status TEXT,
  error_message TEXT,
  metadata JSONB,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- TABLE 6: LOCAL TASKS
-- ============================================
CREATE TABLE IF NOT EXISTS public.local_tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT DEFAULT 'dainik',
  prahar TEXT DEFAULT 'purvahna',
  status TEXT DEFAULT 'pending',
  priority INTEGER DEFAULT 1,
  due_date TIMESTAMPTZ,
  is_completed BOOLEAN DEFAULT FALSE,
  time TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- TABLE 7: JOURNAL ENTRIES
-- ============================================
CREATE TABLE IF NOT EXISTS public.journal_entries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT,
  mood_rating INTEGER CHECK (mood_rating >= 1 AND mood_rating <= 5),
  image_urls TEXT[],
  audio_url TEXT,
  date DATE,
  word_count INTEGER,
  writing_time INTEGER,
  has_photo BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- TABLE 8: GUIDED SESSIONS
-- ============================================
CREATE TABLE IF NOT EXISTS public.sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  title_hindi TEXT,
  description TEXT,
  category TEXT NOT NULL CHECK (category IN ('meditation', 'pranayama', 'yoga')),
  media_type TEXT NOT NULL CHECK (media_type IN ('youtube', 'audio', 'video')),
  media_url TEXT,
  youtube_url TEXT,
  video_url TEXT,
  audio_url TEXT,
  thumbnail_url TEXT,
  duration INTEGER DEFAULT 600,
  difficulty INTEGER DEFAULT 3 CHECK (difficulty >= 1 AND difficulty <= 5),
  is_premium BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  view_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON public.user_profiles(email);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON public.subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON public.subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_routine_tracking_user_id ON public.routine_tracking(user_id);
CREATE INDEX IF NOT EXISTS idx_routine_tracking_date ON public.routine_tracking(tracking_date);
CREATE INDEX IF NOT EXISTS idx_local_tasks_user_id ON public.local_tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_local_tasks_category ON public.local_tasks(category);
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_id ON public.journal_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_category ON public.sessions(category);
CREATE INDEX IF NOT EXISTS idx_sessions_active ON public.sessions(is_active);

-- ============================================
-- TRIGGER FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- TRIGGERS
-- ============================================
DROP TRIGGER IF EXISTS set_user_profiles_updated_at ON public.user_profiles;
CREATE TRIGGER set_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_sessions_updated_at ON public.sessions;
CREATE TRIGGER set_sessions_updated_at
    BEFORE UPDATE ON public.sessions
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_journal_entries_updated_at ON public.journal_entries;
CREATE TRIGGER set_journal_entries_updated_at
    BEFORE UPDATE ON public.journal_entries
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================
-- ENABLE RLS ON ALL TABLES
-- ============================================
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routine_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.local_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

-- ============================================
-- RLS POLICIES
-- ============================================

-- User Profiles
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
CREATE POLICY "Users can view own profile" ON public.user_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.user_profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.user_profiles FOR UPDATE USING (auth.uid() = id);

-- Sessions (Public read, authenticated write)
DROP POLICY IF EXISTS "Anyone can read sessions" ON public.sessions;
DROP POLICY IF EXISTS "Authenticated users can manage sessions" ON public.sessions;
CREATE POLICY "Anyone can read sessions" ON public.sessions FOR SELECT USING (true);
CREATE POLICY "Authenticated users can manage sessions" ON public.sessions FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Local Tasks
DROP POLICY IF EXISTS "Users can manage own tasks" ON public.local_tasks;
CREATE POLICY "Users can manage own tasks" ON public.local_tasks FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Journal Entries
DROP POLICY IF EXISTS "Users can manage own journal" ON public.journal_entries;
CREATE POLICY "Users can manage own journal" ON public.journal_entries FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Routine Tracking
DROP POLICY IF EXISTS "Users can manage own tracking" ON public.routine_tracking;
CREATE POLICY "Users can manage own tracking" ON public.routine_tracking FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Subscriptions
DROP POLICY IF EXISTS "Users can view own subscriptions" ON public.subscriptions;
CREATE POLICY "Users can view own subscriptions" ON public.subscriptions FOR SELECT USING (auth.uid() = user_id);

-- ============================================
-- SAMPLE SESSION DATA
-- ============================================
INSERT INTO public.sessions (title, title_hindi, description, category, media_type, media_url, youtube_url, duration, difficulty) VALUES
('Morning Meditation', 'प्रातःकालीन ध्यान', 'Start your day with peaceful awareness.', 'meditation', 'youtube', 'https://www.youtube.com/watch?v=inpok4MKVLM', 'https://www.youtube.com/watch?v=inpok4MKVLM', 900, 2),
('Deep Sleep Meditation', 'गहरी नींद ध्यान', 'Drift into peaceful slumber.', 'meditation', 'youtube', 'https://www.youtube.com/watch?v=aEqlQvczMJQ', 'https://www.youtube.com/watch?v=aEqlQvczMJQ', 1800, 2),
('Anulom Vilom', 'अनुलोम विलोम', 'Alternate nostril breathing technique.', 'pranayama', 'youtube', 'https://www.youtube.com/watch?v=8VwufJrUhic', 'https://www.youtube.com/watch?v=8VwufJrUhic', 600, 2),
('Kapalbhati', 'कपालभाति', 'Skull shining breath for detoxification.', 'pranayama', 'youtube', 'https://www.youtube.com/watch?v=5QfL51bL1v0', 'https://www.youtube.com/watch?v=5QfL51bL1v0', 600, 4),
('Surya Namaskar', 'सूर्य नमस्कार', 'Complete sequence of 12 poses.', 'yoga', 'youtube', 'https://www.youtube.com/watch?v=AbPufvvYiSw', 'https://www.youtube.com/watch?v=AbPufvvYiSw', 900, 3),
('Gentle Evening Yoga', 'सांध्य योग', 'Relaxing poses to unwind.', 'yoga', 'youtube', 'https://www.youtube.com/watch?v=v7AYKMP6rOE', 'https://www.youtube.com/watch?v=v7AYKMP6rOE', 1800, 2)
ON CONFLICT DO NOTHING;

-- ============================================
-- HELPER FUNCTIONS
-- ============================================
CREATE OR REPLACE FUNCTION public.has_active_subscription(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM public.subscriptions WHERE user_id = p_user_id AND status = 'active' AND expires_at > NOW());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_admin(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM public.admin_roles WHERE user_id = p_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- SETUP COMPLETE!
-- ============================================
