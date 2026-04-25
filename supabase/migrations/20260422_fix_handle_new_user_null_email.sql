-- Fixes "Database error saving new user" for Sign in with Apple (and any OAuth) when
-- auth.users.email is null or empty: public.users.token_identifier is NOT NULL and must
-- not use NEW.email directly. Also makes the insert idempotent on id conflict.
--
-- If Postgres logs: column "user_id" of relation "users" does not exist, your
-- public.users table predates the app schema: we add `user_id` and backfill from id.
-- For a full schema + trigger reset, run the newer 20260424 migration instead
-- (or in addition) if errors persist.
-- Run: supabase db push, or paste into Supabase SQL Editor on your project.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS user_id text,
  ADD COLUMN IF NOT EXISTS subscription_status text,
  ADD COLUMN IF NOT EXISTS subscription_type text;

-- RLS and app code use user_id = auth id string; backfill for existing rows, then require uniqueness
UPDATE public.users
SET user_id = id::text
WHERE user_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS users_user_id_key ON public.users (user_id);

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  safe_email text := NULLIF(TRIM(COALESCE(NEW.email, '')), '');
  token text := COALESCE(safe_email, NEW.id::text);
BEGIN
  INSERT INTO public.users (
    id,
    user_id,
    email,
    name,
    full_name,
    avatar_url,
    token_identifier,
    created_at,
    updated_at,
    subscription_status,
    subscription_type
  ) VALUES (
    NEW.id,
    NEW.id::text,
    safe_email,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'full_name'),
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url',
    token,
    NEW.created_at,
    NEW.updated_at,
    'active',
    'free'
  )
  ON CONFLICT (id) DO UPDATE SET
    email = COALESCE(EXCLUDED.email, public.users.email),
    name = COALESCE(EXCLUDED.name, public.users.name),
    full_name = COALESCE(EXCLUDED.full_name, public.users.full_name),
    avatar_url = COALESCE(EXCLUDED.avatar_url, public.users.avatar_url),
    token_identifier = COALESCE(
      NULLIF(TRIM(COALESCE(EXCLUDED.token_identifier, '')), ''),
      public.users.token_identifier
    ),
    updated_at = now();
  RETURN NEW;
END;
$$;
