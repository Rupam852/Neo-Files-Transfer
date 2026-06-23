-- =============================================================
-- NEO FILES TRANSFER v1.0
-- Migration 006: Enable Supabase Realtime for Admins table
-- =============================================================

-- Add admins table to the supabase_realtime publication to enable broadcasting
alter publication supabase_realtime add table admins;
