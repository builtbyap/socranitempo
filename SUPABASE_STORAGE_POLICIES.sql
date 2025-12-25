-- ============================================
-- Supabase Storage Policies for 'resumes' Bucket
-- ============================================
-- 
-- IMPORTANT: Run these in Supabase SQL Editor
-- Location: Supabase Dashboard → SQL Editor → New Query
--
-- ============================================

-- First, ensure the bucket exists (create it in Dashboard if it doesn't)
-- Or create it via SQL:
-- INSERT INTO storage.buckets (id, name, public) 
-- VALUES ('resumes', 'resumes', true)
-- ON CONFLICT (id) DO NOTHING;

-- ============================================
-- POLICY 1: Allow authenticated users to INSERT (upload) resumes
-- ============================================
CREATE POLICY "Allow authenticated users to upload resumes"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'resumes' AND
  -- Optional: Restrict file types
  (storage.extension(name) IN ('pdf', 'doc', 'docx'))
);

-- ============================================
-- POLICY 2: Allow public SELECT (read/download) resumes
-- ============================================
-- Use this if you want resumes to be publicly accessible
CREATE POLICY "Allow public to read resumes"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'resumes');

-- ============================================
-- POLICY 3: Allow authenticated users to UPDATE their own resumes
-- ============================================
-- Optional: If you want users to be able to update their resumes
CREATE POLICY "Allow users to update their own resumes"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'resumes'
  -- Uncomment below to restrict to own files only:
  -- AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'resumes'
  -- Uncomment below to restrict to own files only:
  -- AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================
-- POLICY 4: Allow authenticated users to DELETE their own resumes
-- ============================================
-- Optional: If you want users to be able to delete their resumes
CREATE POLICY "Allow users to delete their own resumes"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'resumes'
  -- Uncomment below to restrict to own files only:
  -- AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================
-- ALTERNATIVE: More Restrictive Policies (Recommended for Production)
-- ============================================
-- Use these if you want users to only access their own resumes

-- Drop the public read policy first if you created it:
-- DROP POLICY IF EXISTS "Allow public to read resumes" ON storage.objects;

-- Then create user-specific policies:

-- Allow authenticated users to read their own resumes
CREATE POLICY "Allow users to read their own resumes"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'resumes' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to upload to their own folder
CREATE POLICY "Allow users to upload to their own folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'resumes' AND
  (storage.foldername(name))[1] = auth.uid()::text AND
  (storage.extension(name) IN ('pdf', 'doc', 'docx'))
);

-- ============================================
-- NOTES:
-- ============================================
-- 
-- 1. The folder structure is: resumes/{userId}/{fileName}
--    - This allows users to have their own folder
--    - The first folder name should match auth.uid()
--
-- 2. File type restrictions:
--    - Currently allows: pdf, doc, docx
--    - Modify the IN clause to add/remove file types
--
-- 3. Public vs Private:
--    - Public policies: Anyone can read resumes (good for sharing)
--    - Private policies: Users can only access their own (more secure)
--
-- 4. To check if policies are working:
--    - Try uploading a file via the app
--    - Check Supabase Dashboard → Storage → resumes bucket
--    - Try accessing the public URL directly
--
-- ============================================
-- QUICK SETUP (Choose One):
-- ============================================
--
-- OPTION A: Public Access (Easier, Less Secure)
-- Run Policies 1 and 2 only
--
-- OPTION B: Private Access (More Secure, Recommended)
-- Run Policies 1, 3, 4, and the "Alternative" policies
-- Make sure your app uses auth.uid() as the folder name
--
-- ============================================

