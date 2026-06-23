-- =============================================================
-- NEO FILES TRANSFER v1.0
-- Migration 004: IP-based Rate Limiting & Cooldown tracking
-- =============================================================

CREATE TABLE IF NOT EXISTS ip_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ip_address TEXT NOT NULL UNIQUE,
  last_request_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  minute_window_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  minute_request_count INTEGER NOT NULL DEFAULT 1,
  hour_window_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  hour_request_count INTEGER NOT NULL DEFAULT 1,
  blocked_until TIMESTAMPTZ DEFAULT NULL
);

-- Enable RLS (Row Level Security)
ALTER TABLE ip_rate_limits ENABLE ROW LEVEL SECURITY;

-- accessed only by Supabase Edge Functions using the service_role client key
