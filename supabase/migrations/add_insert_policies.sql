-- Add INSERT policies for job_posts table
DROP POLICY IF EXISTS "Allow public insert on job_posts" ON job_posts;
CREATE POLICY "Allow public insert on job_posts"
  ON job_posts FOR INSERT
  WITH CHECK (true);

-- Add INSERT policies for profiles table
DROP POLICY IF EXISTS "Allow public insert on profiles" ON profiles;
CREATE POLICY "Allow public insert on profiles"
  ON profiles FOR INSERT
  WITH CHECK (true);

-- Add INSERT policies for emails table (if RLS is enabled)
ALTER TABLE emails ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access on emails" ON emails;
CREATE POLICY "Allow public read access on emails"
  ON emails FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Allow public insert on emails" ON emails;
CREATE POLICY "Allow public insert on emails"
  ON emails FOR INSERT
  WITH CHECK (true);

