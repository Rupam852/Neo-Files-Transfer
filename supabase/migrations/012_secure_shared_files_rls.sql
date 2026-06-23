-- Migration 012: Secure shared_files SELECT policy to prevent bulk metadata leakage
DROP POLICY IF EXISTS "Anyone can read by share hash for download" ON shared_files;

CREATE POLICY "Anyone can read public files by hash"
  ON shared_files FOR SELECT
  USING (sharing_status = 'public');
