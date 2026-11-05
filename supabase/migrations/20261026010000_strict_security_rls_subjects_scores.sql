-- Migration: Strict Security RLS Policies for subjects and subject_scores
-- Role: Security Engineer

-- 1. Ensure tables exist (if not already created)
CREATE TABLE IF NOT EXISTS public.subjects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (length(trim(name)) > 0),
  code text UNIQUE,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.subject_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_id uuid NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
  class_id uuid NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  score numeric(5, 2) NOT NULL CHECK (score >= 0),
  max_score numeric(5, 2) NOT NULL DEFAULT 100 CHECK (max_score > 0),
  graded_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT subject_scores_unique_entry UNIQUE (class_id, user_id, subject_id)
);
-- 2. Enable RLS
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subject_scores ENABLE ROW LEVEL SECURITY;
-- 3. Helper function to check Super Admin / Dev
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM public.users 
    WHERE id = auth.uid() 
      AND is_dev IS TRUE
  );
$$;
-- 4. Helper function to check if current user is a teacher/owner in a given class
CREATE OR REPLACE FUNCTION public.is_class_teacher(p_class_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM public.class_members 
    WHERE class_id = p_class_id 
      AND user_id = auth.uid() 
      AND lower(role) IN ('teacher', 'owner')
  );
$$;
-- ==========================================
-- RLS POLICIES FOR public.subjects
-- ==========================================
DROP POLICY IF EXISTS subjects_select_policy ON public.subjects;
CREATE POLICY subjects_select_policy ON public.subjects
  FOR SELECT
  USING (
    public.is_super_admin()
    OR auth.uid() IS NOT NULL
  );
DROP POLICY IF EXISTS subjects_insert_policy ON public.subjects;
CREATE POLICY subjects_insert_policy ON public.subjects
  FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.class_members 
      WHERE user_id = auth.uid() 
        AND lower(role) IN ('teacher', 'owner')
    )
  );
DROP POLICY IF EXISTS subjects_update_policy ON public.subjects;
CREATE POLICY subjects_update_policy ON public.subjects
  FOR UPDATE
  USING (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.class_members 
      WHERE user_id = auth.uid() 
        AND lower(role) IN ('teacher', 'owner')
    )
  );
DROP POLICY IF EXISTS subjects_delete_policy ON public.subjects;
CREATE POLICY subjects_delete_policy ON public.subjects
  FOR DELETE
  USING (public.is_super_admin());
-- ==========================================
-- RLS POLICIES FOR public.subject_scores
-- ==========================================

-- SELECT: Super Admins (full access), Teachers (managed classes), Students (own scores only)
DROP POLICY IF EXISTS subject_scores_select_policy ON public.subject_scores;
CREATE POLICY subject_scores_select_policy ON public.subject_scores
  FOR SELECT
  USING (
    public.is_super_admin()
    OR user_id = auth.uid()
    OR public.is_class_teacher(class_id)
  );
-- INSERT: Super Admins and Teachers inside their managed classes
DROP POLICY IF EXISTS subject_scores_insert_policy ON public.subject_scores;
CREATE POLICY subject_scores_insert_policy ON public.subject_scores
  FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR public.is_class_teacher(class_id)
  );
-- UPDATE: Super Admins and Teachers inside their managed classes
DROP POLICY IF EXISTS subject_scores_update_policy ON public.subject_scores;
CREATE POLICY subject_scores_update_policy ON public.subject_scores
  FOR UPDATE
  USING (
    public.is_super_admin()
    OR public.is_class_teacher(class_id)
  )
  WITH CHECK (
    public.is_super_admin()
    OR public.is_class_teacher(class_id)
  );
-- DELETE: Super Admins and Teachers inside their managed classes
DROP POLICY IF EXISTS subject_scores_delete_policy ON public.subject_scores;
CREATE POLICY subject_scores_delete_policy ON public.subject_scores
  FOR DELETE
  USING (
    public.is_super_admin()
    OR public.is_class_teacher(class_id)
  );
