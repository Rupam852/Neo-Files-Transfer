-- Migration 021: Allow admins to clear activity logs
CREATE POLICY "Admins can delete activity logs"
  ON activity_logs FOR DELETE
  USING (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()));
