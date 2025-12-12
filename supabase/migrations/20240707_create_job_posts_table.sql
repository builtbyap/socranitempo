-- Create job_posts table if it doesn't exist
CREATE TABLE IF NOT EXISTS job_posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  company TEXT NOT NULL,
  location TEXT,
  posted_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  description TEXT,
  url TEXT,
  salary TEXT,
  job_type TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE job_posts ENABLE ROW LEVEL SECURITY;

-- Create policy for public access (read-only)
DROP POLICY IF EXISTS "Public job posts access";
CREATE POLICY "Public job posts access"
  ON job_posts FOR SELECT
  USING (true);

-- Add table to realtime publication if not already added
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'job_posts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE job_posts;
  END IF;
END
$$;

