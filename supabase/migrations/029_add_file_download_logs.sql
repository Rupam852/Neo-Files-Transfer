-- =============================================================
-- Migration 029: Add File Download Logs for Analytics
-- =============================================================

CREATE TABLE IF NOT EXISTS file_download_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  file_id UUID NOT NULL REFERENCES shared_files(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  custom_link_id UUID REFERENCES custom_share_links(id) ON DELETE SET NULL,
  downloaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  device_type TEXT DEFAULT 'Desktop',
  browser TEXT DEFAULT 'Browser',
  os TEXT DEFAULT 'OS',
  ip_address TEXT DEFAULT NULL
);

CREATE INDEX IF NOT EXISTS idx_file_download_logs_file_id ON file_download_logs(file_id);
CREATE INDEX IF NOT EXISTS idx_file_download_logs_owner_id ON file_download_logs(owner_id);
CREATE INDEX IF NOT EXISTS idx_file_download_logs_downloaded_at ON file_download_logs(downloaded_at DESC);

-- Enable RLS
ALTER TABLE file_download_logs ENABLE ROW LEVEL SECURITY;

-- Owner can read their own files download logs
CREATE POLICY "Owners can view own file download logs"
  ON file_download_logs FOR SELECT
  USING (auth.uid() = owner_id);

-- Anyone (or service role) can insert a download log
CREATE POLICY "Public can log file downloads"
  ON file_download_logs FOR INSERT
  WITH CHECK (TRUE);
