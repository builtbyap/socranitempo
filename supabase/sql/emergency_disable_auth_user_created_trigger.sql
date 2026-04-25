-- Sign-in is blocked with "Database error saving new user" when the trigger on
-- auth.users fails. As a last resort, run this in the Supabase SQL Editor to remove
-- the insert trigger. The iOS app will create public.users in AuthSessionManager
-- (ensureUserRowInDatabase) right after a successful session.
--
-- Re-apply 20260424_ensure_users_table_and_handle_new_user.sql when your schema
-- is fixed so new users get a server-side row again.

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
