-- Normalize the existing subject-rate tables for classroom-scoped indices.
-- Legacy subject_name and nullable classroom_id remain for backwards compatibility.

CREATE TABLE IF NOT EXISTS public.subjects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS subjects_code_unique_idx
  ON public.subjects (code)
  WHERE code IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.classroom_subjects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  classroom_id uuid NOT NULL REFERENCES public.classrooms(id) ON DELETE CASCADE,
  subject_id uuid NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (classroom_id, subject_id)
);

ALTER TABLE public.subject_rates
  ADD COLUMN IF NOT EXISTS classroom_id uuid
    REFERENCES public.classrooms(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS subject_id uuid
    REFERENCES public.subjects(id) ON DELETE RESTRICT;

ALTER TABLE public.subject_rate_transactions
  ADD COLUMN IF NOT EXISTS classroom_id uuid
    REFERENCES public.classrooms(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS subject_id uuid
    REFERENCES public.subjects(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS created_by uuid
    REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS base_impact numeric(6, 2),
  ADD COLUMN IF NOT EXISTS source_type text,
  ADD COLUMN IF NOT EXISTS source_id text;

ALTER TABLE public.subject_rates
  DROP CONSTRAINT IF EXISTS subject_rates_score_check;

ALTER TABLE public.subject_rates
  ADD CONSTRAINT subject_rates_score_check
  CHECK (score >= 0.00 AND score <= 10.00);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'subject_rate_transactions_base_impact_check'
      AND conrelid = 'public.subject_rate_transactions'::regclass
  ) THEN
    ALTER TABLE public.subject_rate_transactions
      ADD CONSTRAINT subject_rate_transactions_base_impact_check
      CHECK (base_impact IS NULL OR base_impact > 0);
  END IF;
END;
$$;

-- Canonicalize aliases that already exist in the legacy transaction data.
UPDATE public.subject_rates
SET subject_name = CASE
  WHEN lower(trim(subject_name)) = 'toan' THEN 'Toán'
  WHEN lower(trim(subject_name)) = 'tieng anh (ngoai ngu 1)'
    THEN 'Tiếng Anh (Ngoại ngữ 1)'
  ELSE trim(subject_name)
END;

UPDATE public.subject_rate_transactions
SET subject_name = CASE
  WHEN lower(trim(subject_name)) = 'toan' THEN 'Toán'
  WHEN lower(trim(subject_name)) = 'tieng anh (ngoai ngu 1)'
    THEN 'Tiếng Anh (Ngoại ngữ 1)'
  ELSE trim(subject_name)
END;

-- Seed the normalized subject catalog from all legacy subject names.
INSERT INTO public.subjects (name)
SELECT DISTINCT subject_name
FROM (
  SELECT subject_name FROM public.subject_rates
  UNION
  SELECT subject_name FROM public.subject_rate_transactions
) AS legacy_subjects
WHERE trim(subject_name) <> ''
  AND NOT EXISTS (
    SELECT 1
    FROM public.subjects
    WHERE lower(trim(subjects.name)) = lower(trim(legacy_subjects.subject_name))
  );

UPDATE public.subject_rates AS rate
SET subject_id = subject.id
FROM public.subjects AS subject
WHERE rate.subject_id IS NULL
  AND lower(trim(subject.name)) = lower(trim(rate.subject_name));

UPDATE public.subject_rate_transactions AS transaction
SET subject_id = subject.id
FROM public.subjects AS subject
WHERE transaction.subject_id IS NULL
  AND lower(trim(subject.name)) = lower(trim(transaction.subject_name));

CREATE INDEX IF NOT EXISTS subject_rates_student_subject_idx
  ON public.subject_rates (student_id, subject_id);

CREATE INDEX IF NOT EXISTS subject_rates_classroom_student_idx
  ON public.subject_rates (classroom_id, student_id);

CREATE INDEX IF NOT EXISTS subject_rate_transactions_student_subject_idx
  ON public.subject_rate_transactions (student_id, subject_id, created_at DESC);

CREATE INDEX IF NOT EXISTS subject_rate_transactions_classroom_idx
  ON public.subject_rate_transactions (classroom_id, created_at DESC);

ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classroom_subjects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS subject_catalog_authenticated_read
  ON public.subjects;
CREATE POLICY subject_catalog_authenticated_read
  ON public.subjects
  FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS classroom_subjects_member_read
  ON public.classroom_subjects;
CREATE POLICY classroom_subjects_member_read
  ON public.classroom_subjects
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.classroom_members AS member
      WHERE member.classroom_id = classroom_subjects.classroom_id
        AND member.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS classroom_subjects_staff_write
  ON public.classroom_subjects;
CREATE POLICY classroom_subjects_staff_write
  ON public.classroom_subjects
  FOR ALL TO authenticated
  USING (public.is_classroom_staff(classroom_id))
  WITH CHECK (public.is_classroom_staff(classroom_id));

GRANT SELECT ON public.subjects TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.classroom_subjects TO authenticated;

NOTIFY pgrst, 'reload schema';
