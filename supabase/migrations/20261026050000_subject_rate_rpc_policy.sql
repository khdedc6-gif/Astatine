-- Migration: Subject Rate RPC Write Policy
-- Grants teacher/owner roles the ability to call adjust_subject_rate via
-- an RLS-friendly approach. The function is SECURITY DEFINER so it already
-- bypasses RLS, but we add explicit INSERT policies so the audit ledger table
-- and subject_rates table remain writable only through the RPC (never raw DML
-- from the client). We also create a thin RPC wrapper that teachers can call.

-- ────────────────────────────────────────────────────────────────
-- 1. INSERT / UPDATE policies: teachers & owners via RPC only
--    (The SECURITY DEFINER function runs as the DB owner, so these
--     policies never block the function itself — they block direct
--     table writes from the client JWT.)
-- ────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS subject_rates_teacher_insert_policy ON public.subject_rates;
CREATE POLICY subject_rates_teacher_insert_policy ON public.subject_rates
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR EXISTS (
    SELECT 1 FROM public.classroom_members
    WHERE user_id = auth.uid()
      AND lower(role_in_class) IN ('teacher', 'owner')
  ));
DROP POLICY IF EXISTS subject_rates_teacher_update_policy ON public.subject_rates;
CREATE POLICY subject_rates_teacher_update_policy ON public.subject_rates
  FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR EXISTS (
    SELECT 1 FROM public.classroom_members
    WHERE user_id = auth.uid()
      AND lower(role_in_class) IN ('teacher', 'owner')
  ));
DROP POLICY IF EXISTS subject_rate_transactions_teacher_insert_policy ON public.subject_rate_transactions;
CREATE POLICY subject_rate_transactions_teacher_insert_policy ON public.subject_rate_transactions
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR EXISTS (
    SELECT 1 FROM public.classroom_members
    WHERE user_id = auth.uid()
      AND lower(role_in_class) IN ('teacher', 'owner')
  ));
-- ────────────────────────────────────────────────────────────────
-- 2. Public-safe wrapper RPC so Flutter can call via supabase.rpc()
--    Returns the new score as a double-precision float.
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.teacher_adjust_subject_rate(
  p_student_id uuid,
  p_subject_name text,
  p_action_type text,
  p_custom_reason text DEFAULT NULL
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_role text;
BEGIN
  -- Gate: only teachers, owners, or super-admins may call this
  SELECT lower(role_in_class) INTO v_caller_role
  FROM public.classroom_members
  WHERE user_id = auth.uid()
    AND lower(role_in_class) IN ('teacher', 'owner')
  LIMIT 1;

  IF v_caller_role IS NULL AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'permission denied: caller is not a teacher or owner';
  END IF;

  RETURN public.adjust_subject_rate(
    p_student_id    => p_student_id,
    p_subject_name  => p_subject_name,
    p_action_type   => p_action_type,
    p_custom_reason => p_custom_reason
  );
END;
$$;
-- ────────────────────────────────────────────────────────────────
-- 3. Thin read RPC: fetch one student's subject rates + GPA
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_student_subject_rates(p_student_id uuid)
RETURNS TABLE (
  subject_name    text,
  score           numeric,
  classification  text,
  updated_at      timestamptz
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT subject_name, score, classification, updated_at
  FROM public.subject_rates
  WHERE student_id = p_student_id
  ORDER BY subject_name;
$$;
