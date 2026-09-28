-- =============================================================
-- Migration: Add APK Description / Release Notes to shared_files
-- =============================================================

ALTER TABLE shared_files ADD COLUMN IF NOT EXISTS apk_description TEXT DEFAULT '';
