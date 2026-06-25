-- Add modified_at column to shared_files table to track when new versions are uploaded
ALTER TABLE shared_files ADD COLUMN IF NOT EXISTS modified_at TIMESTAMPTZ DEFAULT NULL;
