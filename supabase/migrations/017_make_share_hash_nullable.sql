-- Migration: Make unique_share_hash nullable so share links are only generated on-demand
-- Previously every file/folder got a hash at upload time, wasting space for files never shared.
-- Now NULL means "no share link generated yet". A hash is written only when user explicitly generates one.
ALTER TABLE shared_files ALTER COLUMN unique_share_hash DROP NOT NULL;
