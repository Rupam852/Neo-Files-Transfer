-- =============================================================
-- Migration 028: Add Custom Protected Share Links & Download Analytics
-- =============================================================

CREATE TABLE IF NOT EXISTS custom_share_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  file_id UUID NOT NULL REFERENCES shared_files(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  custom_share_hash TEXT NOT NULL UNIQUE,
  pin_code TEXT DEFAULT NULL,
  expires_at TIMESTAMPTZ DEFAULT NULL,
  max_downloads INTEGER DEFAULT NULL,
  download_count INTEGER NOT NULL DEFAULT 0,
  is_one_time BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_custom_share_links_hash ON custom_share_links(custom_share_hash);
CREATE INDEX IF NOT EXISTS idx_custom_share_links_file_id ON custom_share_links(file_id);
CREATE INDEX IF NOT EXISTS idx_custom_share_links_user_id ON custom_share_links(user_id);

-- Enable RLS
ALTER TABLE custom_share_links ENABLE ROW LEVEL SECURITY;

-- Owner policies
CREATE POLICY "Users can view own custom share links"
  ON custom_share_links FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own custom share links"
  ON custom_share_links FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own custom share links"
  ON custom_share_links FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own custom share links"
  ON custom_share_links FOR DELETE
  USING (auth.uid() = user_id);

-- Public read policy for resolving custom share hash metadata safely
CREATE POLICY "Public can resolve active custom share links"
  ON custom_share_links FOR SELECT
  USING (
    (expires_at IS NULL OR expires_at > NOW())
    AND (max_downloads IS NULL OR download_count < max_downloads)
  );

-- Atomic RPC function to increment custom share link download count
CREATE OR REPLACE FUNCTION increment_custom_share_download_count(link_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE custom_share_links
  SET download_count = download_count + 1
  WHERE id = link_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
