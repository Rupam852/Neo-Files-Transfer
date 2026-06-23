-- Migration: Add is_paused column to approved_users table
ALTER TABLE approved_users ADD COLUMN IF NOT EXISTS is_paused BOOLEAN DEFAULT FALSE;
