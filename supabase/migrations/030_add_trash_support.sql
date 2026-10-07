-- =============================================================
-- Migration 030: Add Trash / Recycle Bin Support
-- =============================================================

ALTER TABLE shared_files ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

CREATE INDEX IF NOT EXISTS idx_shared_files_deleted_at ON shared_files(deleted_at);
