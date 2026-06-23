-- Migration 007: Admins Management and role check policies

-- 1. Set the first administrator's role to 'super_admin'
UPDATE admins SET role = 'super_admin' WHERE email = 'rupambairagya08@gmail.com';

-- 2. Drop existing policies on admins (if any) and recreate them
DROP POLICY IF EXISTS "Authenticated users can read admins" ON admins;
DROP POLICY IF EXISTS "Super admins can insert admins" ON admins;
DROP POLICY IF EXISTS "Super admins can delete admins" ON admins;
DROP POLICY IF EXISTS "Super admins can update admins" ON admins;

-- Policy to allow all authenticated users to select admins (needed to check if they are admin during login and for displaying admins list)
CREATE POLICY "Authenticated users can read admins"
  ON admins FOR SELECT
  USING (auth.role() = 'authenticated');

-- Policy to allow only super admins to insert new admins
CREATE POLICY "Super admins can insert admins"
  ON admins FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM admins
      WHERE user_id = auth.uid()
      AND role = 'super_admin'
    )
  );

-- Policy to allow only super admins to delete admins
CREATE POLICY "Super admins can delete admins"
  ON admins FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM admins
      WHERE user_id = auth.uid()
      AND role = 'super_admin'
    )
  );

-- Policy to allow only super admins to update admins
CREATE POLICY "Super admins can update admins"
  ON admins FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM admins
      WHERE user_id = auth.uid()
      AND role = 'super_admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM admins
      WHERE user_id = auth.uid()
      AND role = 'super_admin'
    )
  );
