-- Migration 016: Set replica identity to FULL for approved_users table
-- This enables Supabase Realtime to broadcast UPDATE and DELETE events filtered by columns other than primary key (like email).
ALTER TABLE approved_users REPLICA IDENTITY FULL;
