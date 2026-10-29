ALTER TABLE public.assignments
  ADD COLUMN IF NOT EXISTS passing_score numeric(4, 2) NOT NULL DEFAULT 5;

ALTER TABLE public.questions
  ADD COLUMN IF NOT EXISTS max_points numeric(4, 2) NOT NULL DEFAULT 10;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'assignments_passing_score_range'
      AND conrelid = 'public.assignments'::regclass
  ) THEN
    ALTER TABLE public.assignments
      ADD CONSTRAINT assignments_passing_score_range
      CHECK (passing_score >= 0 AND passing_score <= 10);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'questions_max_points_range'
      AND conrelid = 'public.questions'::regclass
  ) THEN
    ALTER TABLE public.questions
      ADD CONSTRAINT questions_max_points_range
      CHECK (max_points > 0 AND max_points <= 10);
  END IF;
END;
$$;
