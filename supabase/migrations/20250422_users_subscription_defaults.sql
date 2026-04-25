-- Default subscription for app users: active + free. Run in Supabase SQL Editor (or supabase db push).
-- Also updates the auth trigger so new sign-ups get the same values server-side.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS subscription_status text,
  ADD COLUMN IF NOT EXISTS subscription_type text;

UPDATE public.users
SET
  subscription_status = COALESCE(subscription_status, 'active'),
  subscription_type = COALESCE(subscription_type, 'free')
WHERE subscription_status IS NULL
   OR subscription_type IS NULL;

-- Allow a signed-in user to insert their own profile row (e.g. if trigger did not run).
DROP POLICY IF EXISTS "Users can insert own row" ON public.users;
CREATE POLICY "Users can insert own row"
  ON public.users
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- New auth users: include subscription columns (replaces function body from initial-setup).
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'full_name'),
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url',
    COALESCE(NEW.email, NEW.id::text),
    NEW.created_at,
    NEW.updated_at,
    'active',
    'free'
  );
  RETURN NEW;
END;
$$;
