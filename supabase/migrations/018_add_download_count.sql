-- Add download_count column to shared_files table if not exists
ALTER TABLE shared_files ADD COLUMN IF NOT EXISTS download_count INTEGER NOT NULL DEFAULT 0;

-- Create an atomic function to increment download counts securely
CREATE OR REPLACE FUNCTION increment_download_count(file_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE shared_files
  SET download_count = download_count + 1
  WHERE id = file_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
