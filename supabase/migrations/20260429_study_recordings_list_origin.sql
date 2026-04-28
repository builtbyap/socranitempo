-- Distinguish Assistant tab history from Notes/Study imports (link/document rows share study_recordings).

ALTER TABLE public.study_recordings
  ADD COLUMN IF NOT EXISTS list_origin text NOT NULL DEFAULT 'notes_and_study';

COMMENT ON COLUMN public.study_recordings.list_origin IS 'assistant = Assistant tab; notes_and_study = Notes or Study (hidden from Assistant history).';

UPDATE public.study_recordings
SET list_origin = 'assistant'
WHERE audio_filename IS NOT NULL
  AND audio_filename LIKE 'assistant_%';
