-- Migration 025: Clean up auth.users account when an administrator is deleted from admins table

-- Trigger function for admins deletion
CREATE OR REPLACE FUNCTION public.tr_admin_delete()
RETURNS TRIGGER AS $$
BEGIN
  -- When admin is deleted, wipe their auth.users account completely
  PERFORM public.handle_user_deletion_by_email(OLD.email);
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for deletes on admins
CREATE OR REPLACE TRIGGER tr_on_admin_delete
  AFTER DELETE ON public.admins
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_admin_delete();
