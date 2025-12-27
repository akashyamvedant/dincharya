-- ============================================
-- DINCHARYA - COMPLETE DATABASE MIGRATION
-- Version: 2.0 - Security & Feature Updates
-- ============================================
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. SUBSCRIPTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id TEXT NOT NULL,
  plan_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active', -- 'active', 'expired', 'cancelled', 'pending'
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

-- 2. ADMIN ROLES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.admin_roles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'admin', -- 'admin', 'super_admin'
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  granted_by UUID REFERENCES auth.users(id)
);

-- 3. ROUTINE TRACKING TABLE (for cloud sync)
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

-- 4. PAYMENT AUDIT LOG
-- ============================================
CREATE TABLE IF NOT EXISTS public.payment_audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL, -- 'payment_initiated', 'payment_success', 'payment_failed', 'signature_verified', 'signature_failed'
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

-- 5. LOCAL TASKS TABLE (if not exists)
-- ============================================
CREATE TABLE IF NOT EXISTS public.local_tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT DEFAULT 'local_work',
  status TEXT DEFAULT 'pending',
  priority INTEGER DEFAULT 1,
  due_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. JOURNAL ENTRIES TABLE (if not exists)
-- ============================================
CREATE TABLE IF NOT EXISTS public.journal_entries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT,
  mood_rating INTEGER CHECK (mood_rating >= 1 AND mood_rating <= 5),
  image_urls TEXT[],
  audio_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================

-- Subscriptions indexes
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON public.subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON public.subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_expires_at ON public.subscriptions(expires_at);
CREATE INDEX IF NOT EXISTS idx_subscriptions_order_id ON public.subscriptions(razorpay_order_id);

-- Tracking indexes
CREATE INDEX IF NOT EXISTS idx_routine_tracking_user_id ON public.routine_tracking(user_id);
CREATE INDEX IF NOT EXISTS idx_routine_tracking_date ON public.routine_tracking(tracking_date);
CREATE INDEX IF NOT EXISTS idx_routine_tracking_user_date ON public.routine_tracking(user_id, tracking_date);

-- Audit log indexes
CREATE INDEX IF NOT EXISTS idx_payment_audit_user_id ON public.payment_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_audit_created_at ON public.payment_audit_log(created_at);
CREATE INDEX IF NOT EXISTS idx_payment_audit_event_type ON public.payment_audit_log(event_type);

-- Tasks indexes
CREATE INDEX IF NOT EXISTS idx_local_tasks_user_id ON public.local_tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_local_tasks_due_date ON public.local_tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_local_tasks_status ON public.local_tasks(status);

-- Journal indexes
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_id ON public.journal_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_journal_entries_created_at ON public.journal_entries(created_at);

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routine_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.local_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "Service role can manage subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "Users can view own admin role" ON public.admin_roles;
DROP POLICY IF EXISTS "Service role can manage admin roles" ON public.admin_roles;
DROP POLICY IF EXISTS "Users can view own tracking" ON public.routine_tracking;
DROP POLICY IF EXISTS "Users can insert own tracking" ON public.routine_tracking;
DROP POLICY IF EXISTS "Users can update own tracking" ON public.routine_tracking;
DROP POLICY IF EXISTS "Users can view own audit logs" ON public.payment_audit_log;
DROP POLICY IF EXISTS "Service role full access payment_audit" ON public.payment_audit_log;
DROP POLICY IF EXISTS "Users can manage own tasks" ON public.local_tasks;
DROP POLICY IF EXISTS "Users can manage own journal" ON public.journal_entries;

-- SUBSCRIPTIONS POLICIES
CREATE POLICY "Users can view own subscriptions"
    ON public.subscriptions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage subscriptions"
    ON public.subscriptions FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- ADMIN ROLES POLICIES
CREATE POLICY "Users can view own admin role"
    ON public.admin_roles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage admin roles"
    ON public.admin_roles FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- ROUTINE TRACKING POLICIES
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

-- PAYMENT AUDIT LOG POLICIES
CREATE POLICY "Users can view own audit logs"
    ON public.payment_audit_log FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Service role full access payment_audit"
    ON public.payment_audit_log FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- LOCAL TASKS POLICIES
CREATE POLICY "Users can manage own tasks"
    ON public.local_tasks FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- JOURNAL ENTRIES POLICIES
CREATE POLICY "Users can manage own journal"
    ON public.journal_entries FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ============================================
-- TRIGGERS FOR UPDATED_AT
-- ============================================

-- Subscriptions trigger
DROP TRIGGER IF EXISTS set_subscriptions_updated_at ON public.subscriptions;
CREATE TRIGGER set_subscriptions_updated_at
    BEFORE UPDATE ON public.subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- Local tasks trigger
DROP TRIGGER IF EXISTS set_tasks_updated_at ON public.local_tasks;
CREATE TRIGGER set_tasks_updated_at
    BEFORE UPDATE ON public.local_tasks
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- Journal entries trigger
DROP TRIGGER IF EXISTS set_journal_updated_at ON public.journal_entries;
CREATE TRIGGER set_journal_updated_at
    BEFORE UPDATE ON public.journal_entries
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Function to check active subscription
CREATE OR REPLACE FUNCTION public.has_active_subscription(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE user_id = p_user_id
    AND status = 'active'
    AND expires_at > NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check admin role
CREATE OR REPLACE FUNCTION public.is_admin(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.admin_roles
    WHERE user_id = p_user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Run these after migration to verify:

-- SELECT * FROM public.subscriptions LIMIT 1;
-- SELECT * FROM public.admin_roles LIMIT 1;
-- SELECT * FROM public.routine_tracking LIMIT 1;
-- SELECT * FROM public.payment_audit_log LIMIT 1;
-- SELECT public.has_active_subscription(auth.uid());
-- SELECT public.is_admin(auth.uid());

-- ============================================
-- MIGRATION COMPLETE
-- ============================================
