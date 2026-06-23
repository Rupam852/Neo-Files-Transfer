-- Migration 015: Allow admins to update approved_users to pause/resume accounts
CREATE POLICY "Admins can update approved"
  ON approved_users FOR UPDATE
  USING (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()));
