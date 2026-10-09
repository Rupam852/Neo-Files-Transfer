-- =============================================================
-- Migration 032: User FCM Push Notification Tokens Table & RLS
-- =============================================================

CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    fcm_token TEXT NOT NULL,
    device_name TEXT DEFAULT 'Android Device',
    platform TEXT DEFAULT 'android',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT user_fcm_tokens_user_device_unique UNIQUE (user_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id ON public.user_fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_token ON public.user_fcm_tokens(fcm_token);

-- Grant table permissions to all roles
GRANT ALL ON TABLE public.user_fcm_tokens TO anon, authenticated, service_role;

-- Enable Row Level Security (RLS)
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Drop old policies to prevent conflicts
DROP POLICY IF EXISTS "Users can manage own tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Users can insert own tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Users can update own tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Users can select own tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Users can delete own tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Service role full access on user_fcm_tokens" ON public.user_fcm_tokens;

-- 1. Full access for authenticated user on their own rows
CREATE POLICY "Users can manage own tokens"
ON public.user_fcm_tokens
FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 2. Service role full bypass access
CREATE POLICY "Service role full access on user_fcm_tokens"
ON public.user_fcm_tokens
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
