-- Migration 009: Set replica identity to full on admins table for realtime deletes

ALTER TABLE admins REPLICA IDENTITY FULL;
