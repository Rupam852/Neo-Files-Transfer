-- =============================================================
-- Migration 031: Add In-App Notifications & Realtime Triggers
-- =============================================================

-- 1. Create Notifications Table
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'download', -- 'download', 'approval', 'system', 'security'
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(user_id, is_read);

-- 2. Schema and Table Permissions (Crucial for Anon & Authenticated)
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.notifications TO anon, authenticated, service_role;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'file_download_logs') THEN
    GRANT ALL ON TABLE public.file_download_logs TO anon, authenticated, service_role;
  END IF;
END $$;

-- 3. Enable Row Level Security (RLS)
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
DROP POLICY IF EXISTS "Anyone or service can insert notifications" ON notifications;

-- RLS Policies
CREATE POLICY "Users can view own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own notifications"
  ON notifications FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Anyone or service can insert notifications"
  ON notifications FOR INSERT
  WITH CHECK (TRUE);

-- 4. Enable Supabase Realtime for Notifications Table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
  END IF;
END $$;

ALTER TABLE notifications REPLICA IDENTITY FULL;

-- -------------------------------------------------------------
-- Trigger 1: Auto-create notification on file download (with debounce)
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION notify_on_file_download()
RETURNS TRIGGER AS $$
DECLARE
  v_file_name TEXT;
  v_recent_count INT;
BEGIN
  -- Avoid duplicate notification if logged multiple times within 5 seconds
  SELECT COUNT(*) INTO v_recent_count
  FROM notifications
  WHERE user_id = NEW.owner_id
    AND type = 'download'
    AND metadata->>'file_id' = NEW.file_id::text
    AND created_at >= (NOW() - INTERVAL '5 seconds');

  IF v_recent_count = 0 THEN
    SELECT file_name INTO v_file_name
    FROM shared_files
    WHERE id = NEW.file_id;

    DECLARE
      v_details TEXT := '';
    BEGIN
      IF NEW.browser IS NOT NULL AND NEW.os IS NOT NULL THEN
        v_details := ' via ' || NEW.browser || ' on ' || NEW.os;
      ELSIF NEW.browser IS NOT NULL THEN
        v_details := ' via ' || NEW.browser;
      ELSIF NEW.device_type IS NOT NULL THEN
        v_details := ' via ' || NEW.device_type;
      END IF;

      INSERT INTO notifications (user_id, title, message, type, metadata)
      VALUES (
        NEW.owner_id,
        'File Downloaded 📥',
        'Someone downloaded "' || COALESCE(v_file_name, 'Shared file') || '"' || v_details,
        'download',
        jsonb_build_object(
          'file_id', NEW.file_id,
          'file_name', v_file_name,
          'device_type', NEW.device_type,
          'browser', NEW.browser,
          'os', NEW.os
        )
      );
    END;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'file_download_logs') THEN
    DROP TRIGGER IF EXISTS trg_notify_on_file_download ON file_download_logs;
    CREATE TRIGGER trg_notify_on_file_download
      AFTER INSERT ON file_download_logs
      FOR EACH ROW
      EXECUTE FUNCTION notify_on_file_download();
  END IF;
END $$;

-- -------------------------------------------------------------
-- Trigger 2: Auto-create notification on user registration approval
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION notify_on_user_approval()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Resolve auth.users id by email
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE LOWER(email) = LOWER(NEW.email)
  LIMIT 1;

  IF v_user_id IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type, metadata)
    VALUES (
      v_user_id,
      'Account Approved 🎉',
      'Your registration has been approved by the administrator. You now have full access to Neo Files Transfer.',
      'approval',
      jsonb_build_object('approved_at', NOW(), 'email', NEW.email)
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_on_user_approval ON approved_users;
CREATE TRIGGER trg_notify_on_user_approval
  AFTER INSERT ON approved_users
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_user_approval();

-- -------------------------------------------------------------
-- Trigger 3: Notification on Account Pause / Resume Status Change
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION notify_on_user_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
BEGIN
  IF (OLD.is_paused IS DISTINCT FROM NEW.is_paused) THEN
    SELECT id INTO v_user_id
    FROM auth.users
    WHERE LOWER(email) = LOWER(NEW.email)
    LIMIT 1;

    IF v_user_id IS NOT NULL THEN
      IF NEW.is_paused = TRUE THEN
        INSERT INTO notifications (user_id, title, message, type, metadata)
        VALUES (
          v_user_id,
          'Account Access Paused ⚠️',
          'Your account access has been temporarily suspended by an administrator.',
          'system',
          jsonb_build_object('paused_at', NOW())
        );
      ELSE
        INSERT INTO notifications (user_id, title, message, type, metadata)
        VALUES (
          v_user_id,
          'Account Access Restored ✅',
          'Your account access has been resumed by the administrator. Welcome back!',
          'system',
          jsonb_build_object('resumed_at', NOW())
        );
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_on_user_status_change ON approved_users;
CREATE TRIGGER trg_notify_on_user_status_change
  AFTER UPDATE ON approved_users
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_user_status_change();

