-- Per-user study data: notes, flashcard decks, quizzes, recordings. Synced from the iOS app.
-- RLS: each row’s user_id must equal auth.uid().

-- Notes
CREATE TABLE IF NOT EXISTS public.study_notes (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  title text NOT NULL DEFAULT '',
  body text NOT NULL DEFAULT '',
  tags text[] NOT NULL DEFAULT ARRAY[]::text[],
  updated_at timestamptz NOT NULL DEFAULT (timezone('utc'::text, now())),
  audio_filename text
);

-- Flashcard decks (cards stored as jsonb)
CREATE TABLE IF NOT EXISTS public.study_decks (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  title text NOT NULL DEFAULT '',
  topic text NOT NULL DEFAULT '',
  cards jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT (timezone('utc'::text, now()))
);

-- Quizzes
CREATE TABLE IF NOT EXISTS public.study_quizzes (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  title text NOT NULL DEFAULT '',
  topic text NOT NULL DEFAULT '',
  questions jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT (timezone('utc'::text, now()))
);

-- Assistant / Notes recordings (metadata only; audio files stay on device unless you add Storage)
CREATE TABLE IF NOT EXISTS public.study_recordings (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  title text NOT NULL DEFAULT '',
  kind text NOT NULL DEFAULT 'other',
  updated_at timestamptz NOT NULL DEFAULT (timezone('utc'::text, now())),
  audio_filename text,
  source_url text,
  generated_note_id uuid
);

CREATE INDEX IF NOT EXISTS study_notes_user_id ON public.study_notes (user_id);
CREATE INDEX IF NOT EXISTS study_decks_user_id ON public.study_decks (user_id);
CREATE INDEX IF NOT EXISTS study_quizzes_user_id ON public.study_quizzes (user_id);
CREATE INDEX IF NOT EXISTS study_recordings_user_id ON public.study_recordings (user_id);

ALTER TABLE public.study_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_recordings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "study_notes own all" ON public.study_notes;
CREATE POLICY "study_notes own all"
  ON public.study_notes
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "study_decks own all" ON public.study_decks;
CREATE POLICY "study_decks own all"
  ON public.study_decks
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "study_quizzes own all" ON public.study_quizzes;
CREATE POLICY "study_quizzes own all"
  ON public.study_quizzes
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "study_recordings own all" ON public.study_recordings;
CREATE POLICY "study_recordings own all"
  ON public.study_recordings
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
