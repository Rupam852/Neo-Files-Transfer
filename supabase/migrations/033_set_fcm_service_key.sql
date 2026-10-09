-- =============================================================
-- Migration 033: Set Firebase Admin SDK Private Key in System Settings
-- =============================================================

-- Set via Supabase Dashboard SQL editor or system_settings:
-- INSERT INTO public.system_settings (key, value)
-- VALUES ('fcm_service_account_private_key', '"<YOUR_FIREBASE_PRIVATE_KEY>"'::jsonb)
-- ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
