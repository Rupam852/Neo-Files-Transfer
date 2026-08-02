-- Function to automatically purge activity logs older than 7 days
CREATE OR REPLACE FUNCTION cleanup_old_activity_logs()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM activity_logs WHERE created_at < NOW() - INTERVAL '7 days';
  DELETE FROM admin_activity_logs WHERE created_at < NOW() - INTERVAL '7 days';
END;
$$;

-- Execute initial cleanup
SELECT cleanup_old_activity_logs();
