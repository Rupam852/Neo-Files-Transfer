-- =============================================================
-- NEO FILES TRANSFER v1.0
-- Safe re-apply: Drop and recreate all RLS policies
-- =============================================================

-- Drop existing policies (idempotent)
DROP POLICY IF EXISTS "Users can read own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view own files" ON shared_files;
DROP POLICY IF EXISTS "Users can insert own files" ON shared_files;
DROP POLICY IF EXISTS "Users can update own files" ON shared_files;
DROP POLICY IF EXISTS "Users can delete own files" ON shared_files;
DROP POLICY IF EXISTS "Anyone can read by share hash for download" ON shared_files;
DROP POLICY IF EXISTS "Users can view own file versions" ON file_versions;
DROP POLICY IF EXISTS "Users can insert own file versions" ON file_versions;
DROP POLICY IF EXISTS "Users can delete own file versions" ON file_versions;
DROP POLICY IF EXISTS "Users can view own logs" ON activity_logs;
DROP POLICY IF EXISTS "Users can insert own logs" ON activity_logs;
DROP POLICY IF EXISTS "Anyone can submit registration" ON pending_registrations;
DROP POLICY IF EXISTS "Authenticated users can read registrations" ON pending_registrations;
DROP POLICY IF EXISTS "Authenticated users can update registrations" ON pending_registrations;
DROP POLICY IF EXISTS "Authenticated users can delete registrations" ON pending_registrations;
DROP POLICY IF EXISTS "Authenticated users can read approved" ON approved_users;
DROP POLICY IF EXISTS "Authenticated users can insert approved" ON approved_users;
DROP POLICY IF EXISTS "Authenticated users can delete approved" ON approved_users;
DROP POLICY IF EXISTS "Authenticated users can read admins" ON admins;
DROP POLICY IF EXISTS "Authenticated users can insert admin logs" ON admin_activity_logs;
DROP POLICY IF EXISTS "Authenticated users can read admin logs" ON admin_activity_logs;
DROP POLICY IF EXISTS "Anyone can read settings" ON system_settings;
DROP POLICY IF EXISTS "Authenticated users can update settings" ON system_settings;
DROP POLICY IF EXISTS "Authenticated users can insert settings" ON system_settings;

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE file_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE pending_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE approved_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

-- USER PROFILES
CREATE POLICY "Users can read own profile"
  ON user_profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON user_profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON user_profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- SHARED FILES
CREATE POLICY "Users can view own files"
  ON shared_files FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own files"
  ON shared_files FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own files"
  ON shared_files FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own files"
  ON shared_files FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Anyone can read by share hash for download"
  ON shared_files FOR SELECT
  USING (true);

-- FILE VERSIONS
CREATE POLICY "Users can view own file versions"
  ON file_versions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM shared_files
      WHERE shared_files.id = file_versions.file_id
      AND shared_files.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own file versions"
  ON file_versions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM shared_files
      WHERE shared_files.id = file_versions.file_id
      AND shared_files.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own file versions"
  ON file_versions FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM shared_files
      WHERE shared_files.id = file_versions.file_id
      AND shared_files.user_id = auth.uid()
    )
  );

-- ACTIVITY LOGS
CREATE POLICY "Users can view own logs"
  ON activity_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own logs"
  ON activity_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- PENDING REGISTRATIONS
CREATE POLICY "Anyone can submit registration"
  ON pending_registrations FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Authenticated users can read registrations"
  ON pending_registrations FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update registrations"
  ON pending_registrations FOR UPDATE
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete registrations"
  ON pending_registrations FOR DELETE
  USING (auth.role() = 'authenticated');

-- APPROVED USERS
CREATE POLICY "Authenticated users can read approved"
  ON approved_users FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert approved"
  ON approved_users FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete approved"
  ON approved_users FOR DELETE
  USING (auth.role() = 'authenticated');

-- ADMINS
CREATE POLICY "Authenticated users can read admins"
  ON admins FOR SELECT
  USING (auth.role() = 'authenticated');

-- ADMIN ACTIVITY LOGS
CREATE POLICY "Authenticated users can insert admin logs"
  ON admin_activity_logs FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can read admin logs"
  ON admin_activity_logs FOR SELECT
  USING (auth.role() = 'authenticated');

-- SYSTEM SETTINGS
CREATE POLICY "Anyone can read settings"
  ON system_settings FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can update settings"
  ON system_settings FOR UPDATE
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert settings"
  ON system_settings FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Insert default settings if not present
INSERT INTO system_settings (key, value) VALUES
  ('maintenance_mode', 'false'::jsonb),
  ('downloads_enabled', 'true'::jsonb),
  ('sharing_enabled', 'true'::jsonb),
  ('allowed_file_types', '"pdf,jpg,png,zip,docx,xlsx,pptx,mp4"'::jsonb),
  ('max_upload_size', '104857600'::jsonb)
ON CONFLICT (key) DO NOTHING;
