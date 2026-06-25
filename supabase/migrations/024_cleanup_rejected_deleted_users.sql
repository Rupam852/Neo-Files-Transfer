-- Migration 024: Automated cleanup of rejected/deleted users from auth.users

-- Helper function to delete user by email (Security Definer runs as superuser)
CREATE OR REPLACE FUNCTION public.handle_user_deletion_by_email(target_email TEXT)
RETURNS VOID AS $$
BEGIN
  -- Deleting from auth.users cascades to user_profiles, shared_files, activity_logs etc.
  DELETE FROM auth.users WHERE LOWER(email) = LOWER(target_email);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger function for pending_registrations status updates
CREATE OR REPLACE FUNCTION public.tr_pending_registration_status_update()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'rejected' THEN
    PERFORM public.handle_user_deletion_by_email(NEW.email);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for updates on pending_registrations
CREATE OR REPLACE TRIGGER tr_on_pending_registration_status_update
  AFTER UPDATE OF status ON public.pending_registrations
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_pending_registration_status_update();

-- Trigger function for pending_registrations deletion
CREATE OR REPLACE FUNCTION public.tr_pending_registration_delete()
RETURNS TRIGGER AS $$
BEGIN
  -- If registration was rejected or pending (not approved), clean up their auth.users account
  IF OLD.status != 'approved' THEN
    PERFORM public.handle_user_deletion_by_email(OLD.email);
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for deletes on pending_registrations
CREATE OR REPLACE TRIGGER tr_on_pending_registration_delete
  AFTER DELETE ON public.pending_registrations
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_pending_registration_delete();

-- Trigger function for approved_users deletion
CREATE OR REPLACE FUNCTION public.tr_approved_user_delete()
RETURNS TRIGGER AS $$
BEGIN
  -- When user is deleted from approved_users, wipe their auth.users account completely
  PERFORM public.handle_user_deletion_by_email(OLD.email);
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for deletes on approved_users
CREATE OR REPLACE TRIGGER tr_on_approved_user_delete
  AFTER DELETE ON public.approved_users
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_approved_user_delete();
