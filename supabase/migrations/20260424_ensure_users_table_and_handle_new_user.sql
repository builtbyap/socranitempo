-- Full alignment for "Database error saving new user" (Apple / Google / any provider).
-- Run the whole file in the Supabase SQL Editor (or `supabase db push`).
-- If the unique index on user_id fails, you have duplicate user_id values — fix with:
--   SELECT user_id, count(*) FROM public.users GROUP BY 1 HAVING count(*) > 1;

-- 0) Base table if missing
CREATE TABLE IF NOT EXISTS public.users (
  id uuid PRIMARY KEY NOT NULL,
  avatar_url text,
  user_id text,
  token_identifier text,
  image text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamptz,
  email text,
  name text,
  full_name text
);

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS user_id text,
  ADD COLUMN IF NOT EXISTS email text,
  ADD COLUMN IF NOT EXISTS name text,
  ADD COLUMN IF NOT EXISTS full_name text,
  ADD COLUMN IF NOT EXISTS avatar_url text,
  ADD COLUMN IF NOT EXISTS image text,
  ADD COLUMN IF NOT EXISTS token_identifier text,
  ADD COLUMN IF NOT EXISTS created_at timestamptz,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz,
  ADD COLUMN IF NOT EXISTS subscription_status text,
  ADD COLUMN IF NOT EXISTS subscription_type text;

-- id must be the primary key for handle_new_user ... ON CONFLICT (id)
DO $pk$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.users'::regclass
      AND contype = 'p'
  ) THEN
    ALTER TABLE public.users ADD PRIMARY KEY (id);
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'public.users: could not add PRIMARY KEY (id) automatically: %', SQLERRM;
END
$pk$;

-- created_at: non-null
UPDATE public.users SET created_at = timezone('utc'::text, now()) WHERE created_at IS NULL;
ALTER TABLE public.users
  ALTER COLUMN created_at SET DEFAULT timezone('utc'::text, now());
ALTER TABLE public.users
  ALTER COLUMN created_at SET NOT NULL;

-- token_identifier: required
UPDATE public.users
SET token_identifier = COALESCE(
  NULLIF(TRIM(COALESCE(token_identifier, '')), ''),
  NULLIF(TRIM(COALESCE(email, '')), ''),
  id::text
)
WHERE token_identifier IS NULL
   OR TRIM(COALESCE(token_identifier, '')) = '';
ALTER TABLE public.users
  ALTER COLUMN token_identifier SET NOT NULL;

UPDATE public.users SET user_id = id::text WHERE user_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS users_user_id_key ON public.users (user_id);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can insert own row" ON public.users;
CREATE POLICY "Users can insert own row"
  ON public.users
  FOR INSERT
  WITH CHECK (auth.uid() = id);

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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.handle_user_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.users AS u
  SET
    email = NEW.email,
    name = COALESCE(NEW.raw_user_meta_data->>'name', u.name),
    full_name = COALESCE(NEW.raw_user_meta_data->>'full_name', u.full_name),
    avatar_url = COALESCE(NEW.raw_user_meta_data->>'avatar_url', u.avatar_url),
    updated_at = NEW.updated_at
  WHERE u.user_id = NEW.id::text;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
CREATE TRIGGER on_auth_user_updated
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_user_update();
