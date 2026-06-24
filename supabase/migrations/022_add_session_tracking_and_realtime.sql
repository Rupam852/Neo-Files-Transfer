-- Migration 022: Add active web and mobile session tracking and enable realtime
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS active_web_session_id TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS active_mobile_session_id TEXT DEFAULT NULL;

-- Add user_profiles to the supabase_realtime publication to enable broadcasting
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'user_profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE user_profiles;
  END IF;
END $$;
