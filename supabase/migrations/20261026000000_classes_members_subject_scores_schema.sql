-- Migration: Classes, Class Members, and Subject Scores Schema with Cascade Deletes
-- Project: Astatine

CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- 1. Ensure public.users table exists and references auth.users
CREATE TABLE IF NOT EXISTS public.users (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text UNIQUE,
  email text UNIQUE,
  full_name text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
-- 2. Create classes table
CREATE TABLE IF NOT EXISTS public.classes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (length(trim(name)) > 0),
  description text,
  code varchar(20) UNIQUE,
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
-- 3. Create class_members table linking classes and users with foreign keys and cascade deletes
CREATE TABLE IF NOT EXISTS public.class_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id uuid NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'teacher', 'assistant', 'owner')),
  joined_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT class_members_class_user_unique UNIQUE (class_id, user_id)
);
-- 4. Create subject_scores table linking classes and users with foreign keys and cascade deletes
CREATE TABLE IF NOT EXISTS public.subject_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id uuid NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  subject_name text NOT NULL CHECK (length(trim(subject_name)) > 0),
  score numeric(5, 2) NOT NULL CHECK (score >= 0),
  max_score numeric(5, 2) NOT NULL DEFAULT 100 CHECK (max_score > 0),
  term text,
  graded_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT subject_scores_unique_entry UNIQUE (class_id, user_id, subject_name)
);
-- 5. Create performance indexes for foreign keys and frequent lookups
CREATE INDEX IF NOT EXISTS classes_created_by_idx ON public.classes (created_by);
CREATE INDEX IF NOT EXISTS class_members_class_id_idx ON public.class_members (class_id);
CREATE INDEX IF NOT EXISTS class_members_user_id_idx ON public.class_members (user_id);
CREATE INDEX IF NOT EXISTS subject_scores_class_id_idx ON public.subject_scores (class_id);
CREATE INDEX IF NOT EXISTS subject_scores_user_id_idx ON public.subject_scores (user_id);
CREATE INDEX IF NOT EXISTS subject_scores_graded_by_idx ON public.subject_scores (graded_by);
-- 6. Enable Row Level Security (RLS) on all new tables
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subject_scores ENABLE ROW LEVEL SECURITY;
-- 7. RLS Policies
-- Classes: authenticated users can view classes they are members of, or created
DROP POLICY IF EXISTS classes_select_policy ON public.classes;
CREATE POLICY classes_select_policy ON public.classes
  FOR SELECT
  USING (
    auth.uid() = created_by
    OR EXISTS (
      SELECT 1 FROM public.class_members
      WHERE class_members.class_id = classes.id
        AND class_members.user_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS classes_insert_policy ON public.classes;
CREATE POLICY classes_insert_policy ON public.classes
  FOR INSERT
  WITH CHECK (auth.uid() = created_by);
DROP POLICY IF EXISTS classes_update_policy ON public.classes;
CREATE POLICY classes_update_policy ON public.classes
  FOR UPDATE
  USING (
    auth.uid() = created_by
    OR EXISTS (
      SELECT 1 FROM public.class_members
      WHERE class_members.class_id = classes.id
        AND class_members.user_id = auth.uid()
        AND class_members.role IN ('teacher', 'owner', 'assistant')
    )
  );
DROP POLICY IF EXISTS classes_delete_policy ON public.classes;
CREATE POLICY classes_delete_policy ON public.classes
  FOR DELETE
  USING (auth.uid() = created_by);
-- Class Members: members can view their class memberships; teachers/owners can manage
DROP POLICY IF EXISTS class_members_select_policy ON public.class_members;
CREATE POLICY class_members_select_policy ON public.class_members
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.class_members AS m
      WHERE m.class_id = class_members.class_id
        AND m.user_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS class_members_insert_policy ON public.class_members;
CREATE POLICY class_members_insert_policy ON public.class_members
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.class_members AS m
      WHERE m.class_id = class_members.class_id
        AND m.user_id = auth.uid()
        AND m.role IN ('teacher', 'owner', 'assistant')
    )
  );
DROP POLICY IF EXISTS class_members_delete_policy ON public.class_members;
CREATE POLICY class_members_delete_policy ON public.class_members
  FOR DELETE
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.class_members AS m
      WHERE m.class_id = class_members.class_id
        AND m.user_id = auth.uid()
        AND m.role IN ('teacher', 'owner', 'assistant')
    )
  );
-- Subject Scores: students can view their own scores; teachers/owners can manage and view all scores in their classes
DROP POLICY IF EXISTS subject_scores_select_policy ON public.subject_scores;
CREATE POLICY subject_scores_select_policy ON public.subject_scores
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.class_members AS m
      WHERE m.class_id = subject_scores.class_id
        AND m.user_id = auth.uid()
        AND m.role IN ('teacher', 'owner', 'assistant')
    )
  );
DROP POLICY IF EXISTS subject_scores_insert_policy ON public.subject_scores;
CREATE POLICY subject_scores_insert_policy ON public.subject_scores
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.class_members AS m
      WHERE m.class_id = subject_scores.class_id
        AND m.user_id = auth.uid()
        AND m.role IN ('teacher', 'owner', 'assistant')
    )
  );
DROP POLICY IF EXISTS subject_scores_update_policy ON public.subject_scores;
CREATE POLICY subject_scores_update_policy ON public.subject_scores
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.class_members AS m
      WHERE m.class_id = subject_scores.class_id
        AND m.user_id = auth.uid()
        AND m.role IN ('teacher', 'owner', 'assistant')
    )
  );
DROP POLICY IF EXISTS subject_scores_delete_policy ON public.subject_scores;
CREATE POLICY subject_scores_delete_policy ON public.subject_scores
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.class_members AS m
      WHERE m.class_id = subject_scores.class_id
        AND m.user_id = auth.uid()
        AND m.role IN ('teacher', 'owner', 'assistant')
    )
  );
