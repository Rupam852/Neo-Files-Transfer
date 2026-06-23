-- =============================================================
-- NEO FILES TRANSFER v1.0
-- Migration 005: Enable Supabase Realtime for Dashboard tables
-- =============================================================

-- Add tables to the supabase_realtime publication to enable broadcasting
alter publication supabase_realtime add table pending_registrations;
alter publication supabase_realtime add table approved_users;
alter publication supabase_realtime add table system_settings;
