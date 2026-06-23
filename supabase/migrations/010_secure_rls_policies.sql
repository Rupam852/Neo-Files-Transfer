-- Migration 010: Secure RLS policies on registrations, approvals, settings, and logs

-- 1. Secure pending_registrations
DROP POLICY IF EXISTS "Authenticated users can read registrations" ON pending_registrations;
DROP POLICY IF EXISTS "Authenticated users can update registrations" ON pending_registrations;
DROP POLICY IF EXISTS "Authenticated users can delete registrations" ON pending_registrations;

CREATE POLICY "Admins can read registrations"
  ON pending_registrations FOR SELECT
  USING (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()));

CREATE POLICY "Admins can update registrations"
  ON pending_registrations FOR UPDATE
  USING (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()));

CREATE POLICY "Admins can delete registrations"
  ON pending_registrations FOR DELETE
  USING (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()));

-- 2. Secure approved_users
DROP POLICY IF EXISTS "Authenticated users can read approved" ON approved_users;
DROP POLICY IF EXISTS "Authenticated users can insert approved" ON approved_users;
DROP POLICY IF EXISTS "Authenticated users can delete approved" ON approved_users;

-- Standard users can only check their own approval, admins can read all
CREATE POLICY "Admins or self can read approved"
  ON approved_users FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid())
    OR (email = (auth.jwt() ->> 'email'))
  );

CREATE POLICY "Admins can insert approved"
  ON approved_users FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()));

CREATE POLICY "Admins can delete approved"
  ON approved_users FOR DELETE
  USING (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()));

-- 3. Secure system_settings
DROP POLICY IF EXISTS "Authenticated users can update settings" ON system_settings;
DROP POLICY IF EXISTS "Authenticated users can insert settings" ON system_settings;

CREATE POLICY "Admins can update settings"
  ON system_settings FOR UPDATE
  USING (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()));

CREATE POLICY "Admins can insert settings"
  ON system_settings FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()));

-- 4. Secure admin_activity_logs
DROP POLICY IF EXISTS "Authenticated users can insert admin logs" ON admin_activity_logs;
DROP POLICY IF EXISTS "Authenticated users can read admin logs" ON admin_activity_logs;

CREATE POLICY "Admins can insert admin logs"
  ON admin_activity_logs FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()));

CREATE POLICY "Admins can read admin logs"
  ON admin_activity_logs FOR SELECT
  USING (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()));
