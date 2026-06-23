-- Migration: Add folders support to shared_files table
ALTER TABLE shared_files ADD COLUMN IF NOT EXISTS is_folder BOOLEAN DEFAULT FALSE;
ALTER TABLE shared_files ADD COLUMN IF NOT EXISTS parent_folder_id UUID REFERENCES shared_files(id) ON DELETE CASCADE;

-- Add index on parent_folder_id to speed up nested navigation queries
CREATE INDEX IF NOT EXISTS idx_shared_files_parent_folder_id ON shared_files(parent_folder_id);
