-- =============================================================
-- Migration: Add APK Version API support to shared_files
-- =============================================================

ALTER TABLE shared_files ADD COLUMN IF NOT EXISTS apk_version TEXT DEFAULT 'v1.0.1';
ALTER TABLE shared_files ADD COLUMN IF NOT EXISTS version_api_key TEXT UNIQUE DEFAULT NULL;

CREATE INDEX IF NOT EXISTS idx_shared_files_version_api_key ON shared_files(version_api_key);
