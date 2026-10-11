-- =============================================================
-- Migration 034: Remove Unused Session Columns from user_profiles
-- =============================================================
-- Note: These columns were originally created for device session
-- tracking in migration 022, but are not used anywhere in the app.

ALTER TABLE user_profiles 
DROP COLUMN IF EXISTS active_web_session_id,
DROP COLUMN IF EXISTS active_mobile_session_id;
