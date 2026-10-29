DO $$
DECLARE
  correct_option_type text;
BEGIN
  SELECT data_type
  INTO correct_option_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'questions'
    AND column_name = 'correct_option';

  IF correct_option_type IS NULL THEN
    RAISE EXCEPTION 'public.questions.correct_option column does not exist';
  END IF;

  IF correct_option_type <> 'integer' THEN
    ALTER TABLE public.questions
      ALTER COLUMN correct_option TYPE integer
      USING CASE
        WHEN upper(trim(correct_option::text)) = 'A' THEN 0
        WHEN upper(trim(correct_option::text)) = 'B' THEN 1
        WHEN upper(trim(correct_option::text)) = 'C' THEN 2
        WHEN upper(trim(correct_option::text)) = 'D' THEN 3
        ELSE trim(correct_option::text)::integer
      END;
  END IF;
END;
$$;

NOTIFY pgrst, 'reload schema';
