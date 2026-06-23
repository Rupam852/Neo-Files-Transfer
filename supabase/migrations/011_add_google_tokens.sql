-- Migration 011: Add google access and refresh tokens to user_profiles table

ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS google_access_token TEXT,
ADD COLUMN IF NOT EXISTS google_refresh_token TEXT;
