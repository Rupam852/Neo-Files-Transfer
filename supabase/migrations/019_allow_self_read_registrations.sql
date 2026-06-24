-- Migration 019: Allow users to read their own pending registrations
DROP POLICY IF EXISTS "Admins can read registrations" ON pending_registrations;

CREATE POLICY "Admins or self can read registrations"
  ON pending_registrations FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid())
    OR (email = (auth.jwt() ->> 'email'))
  );
