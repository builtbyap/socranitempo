-- When the same person signs in with a different provider (e.g. Google then Apple)
-- with the same email, they get a new auth.users id. study_* rows stay keyed to the
-- old id, so RLS hides them. This RPC moves all such rows to the current session
-- when auth.users emails match (normalized).
--
-- Security: only merges from other auth users whose email equals the caller’s
-- canonical email in auth.users (not client-supplied id).

CREATE OR REPLACE FUNCTION public.merge_study_data_from_duplicate_email_accounts()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  me uuid;
  my_email text;
  legacy_id uuid;
BEGIN
  me := auth.uid();
  IF me IS NULL THEN
    RETURN;
  END IF;

  SELECT NULLIF(TRIM(au.email), '') INTO my_email
  FROM auth.users AS au
  WHERE au.id = me;

  IF my_email IS NULL THEN
    RETURN;
  END IF;

  my_email := lower(my_email);

  FOR legacy_id IN
    SELECT au.id
    FROM auth.users AS au
    WHERE au.id <> me
      AND NULLIF(TRIM(au.email), '') IS NOT NULL
      AND lower(TRIM(au.email)) = my_email
  LOOP
    UPDATE public.study_notes SET user_id = me WHERE user_id = legacy_id;
    UPDATE public.study_decks SET user_id = me WHERE user_id = legacy_id;
    UPDATE public.study_quizzes SET user_id = me WHERE user_id = legacy_id;
    UPDATE public.study_recordings SET user_id = me WHERE user_id = legacy_id;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.merge_study_data_from_duplicate_email_accounts() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.merge_study_data_from_duplicate_email_accounts() TO authenticated;
