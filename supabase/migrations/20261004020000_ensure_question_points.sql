ALTER TABLE public.questions
  ADD COLUMN IF NOT EXISTS question_points numeric(4, 2) NOT NULL DEFAULT 10;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'questions'
      AND column_name = 'max_points'
  ) THEN
    UPDATE public.questions
    SET question_points = max_points;

    ALTER TABLE public.questions
      DROP COLUMN max_points;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'questions_question_points_range'
      AND conrelid = 'public.questions'::regclass
  ) THEN
    ALTER TABLE public.questions
      ADD CONSTRAINT questions_question_points_range
      CHECK (question_points > 0 AND question_points <= 10);
  END IF;
END;
$$;

NOTIFY pgrst, 'reload schema';
