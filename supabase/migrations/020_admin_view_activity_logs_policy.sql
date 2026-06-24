-- Migration 020: Allow admins to view all activity logs for auditing
CREATE POLICY "Admins can view all activity logs"
  ON activity_logs FOR SELECT
  USING (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()));
