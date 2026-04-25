-- Full account delete: public profile row, app study history (FK CASCADE from auth.users), and auth user.
-- Called as the signed-in user; only `auth.uid()` is removed.
--
-- Deploy with `supabase db push` or SQL Editor. If `DELETE FROM auth.users` fails with permission
-- errors, your project may restrict auth writes—use a Supabase Edge Function with the service role
-- instead, or free Storage objects the user “owns” (Supabase can block user delete when Storage has owner refs).

CREATE OR REPLACE FUNCTION public.delete_account_and_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  -- Profile row (no FK to auth.users in this project; must delete before auth user).
  DELETE FROM public.users WHERE id = uid;

  -- study_* has ON DELETE CASCADE from auth.users; this delete removes them too.
  DELETE FROM auth.users WHERE id = uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_account_and_data() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_account_and_data() TO authenticated;
