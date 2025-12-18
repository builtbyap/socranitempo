-- Create resume_data table
CREATE TABLE IF NOT EXISTS resume_data (
    id TEXT PRIMARY KEY,
    name TEXT,
    email TEXT,
    phone TEXT,
    skills TEXT[], -- Array of skills
    work_experience JSONB, -- Array of work experience objects
    education JSONB, -- Array of education objects
    projects JSONB, -- Array of project objects
    languages JSONB, -- Array of language objects
    certifications JSONB, -- Array of certification objects
    awards JSONB, -- Array of award objects
    resume_url TEXT,
    parsed_at TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE resume_data ENABLE ROW LEVEL SECURITY;

-- Create policy for SELECT (public read access)
CREATE POLICY "Allow public SELECT on resume_data"
    ON resume_data
    FOR SELECT
    USING (true);

-- Create policy for INSERT (public insert access)
CREATE POLICY "Allow public INSERT on resume_data"
    ON resume_data
    FOR INSERT
    WITH CHECK (true);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_resume_data_email ON resume_data(email);
CREATE INDEX IF NOT EXISTS idx_resume_data_parsed_at ON resume_data(parsed_at DESC);

