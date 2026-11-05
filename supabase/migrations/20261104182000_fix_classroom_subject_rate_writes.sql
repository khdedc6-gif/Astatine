DROP POLICY IF EXISTS subject_rates_select_policy
  ON public.subject_rates;
CREATE POLICY subject_rates_select_policy
  ON public.subject_rates
  FOR SELECT TO authenticated
  USING (
    student_id = auth.uid()
    OR public.is_super_admin()
    OR (
      classroom_id IS NOT NULL
      AND public.is_classroom_staff(classroom_id)
    )
    OR (
      classroom_id IS NULL
      AND EXISTS (
        SELECT 1
        FROM public.class_members AS member
        WHERE member.user_id = auth.uid()
          AND lower(member.role) IN ('teacher', 'owner')
      )
    )
  );

DROP POLICY IF EXISTS subject_rate_transactions_select_policy
  ON public.subject_rate_transactions;
CREATE POLICY subject_rate_transactions_select_policy
  ON public.subject_rate_transactions
  FOR SELECT TO authenticated
  USING (
    student_id = auth.uid()
    OR public.is_super_admin()
    OR (
      classroom_id IS NOT NULL
      AND public.is_classroom_staff(classroom_id)
    )
    OR (
      classroom_id IS NULL
      AND EXISTS (
        SELECT 1
        FROM public.class_members AS member
        WHERE member.user_id = auth.uid()
          AND lower(member.role) IN ('teacher', 'owner')
      )
    )
  );

CREATE OR REPLACE FUNCTION public.apply_classroom_subject_rate_change(
  p_classroom_id uuid,
  p_student_id uuid,
  p_subject_id uuid,
  p_subject_name text,
  p_adjustment_type text,
  p_base_impact numeric,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
DECLARE
  v_subject_name text;
  v_rate_id uuid;
  v_current_score numeric(4, 2);
  v_multiplier numeric;
  v_delta numeric(6, 2);
  v_new_score numeric(4, 2);
  v_classification text;
  v_transaction jsonb;
BEGIN
  IF auth.uid() IS NULL
    OR NOT public.is_classroom_staff(p_classroom_id) THEN
    RAISE EXCEPTION 'Only classroom teachers can change Subject Rate'
      USING ERRCODE = '42501';
  END IF;

  IF p_adjustment_type NOT IN ('BONUS', 'PENALTY')
    OR p_base_impact IS NULL
    OR p_base_impact <= 0
    OR p_base_impact > 10
    OR p_reason IS NULL
    OR length(trim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'Invalid Subject Rate adjustment';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.classroom_members AS member
    WHERE member.classroom_id = p_classroom_id
      AND member.user_id = p_student_id
  ) THEN
    RAISE EXCEPTION 'Student is not a member of this classroom';
  END IF;

  SELECT subject.name
  INTO v_subject_name
  FROM public.subjects AS subject
  WHERE subject.id = p_subject_id;

  IF v_subject_name IS NULL THEN
    RAISE EXCEPTION 'Subject does not exist';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_student_id::text || ':' || p_subject_id::text, 0)
  );

  SELECT rate.id, rate.score
  INTO v_rate_id, v_current_score
  FROM public.subject_rates AS rate
  WHERE rate.student_id = p_student_id
    AND (
      rate.subject_id = p_subject_id
      OR (
        rate.subject_id IS NULL
        AND lower(trim(rate.subject_name)) = lower(trim(v_subject_name))
      )
    )
  ORDER BY rate.updated_at DESC
  LIMIT 1
  FOR UPDATE;

  v_current_score := COALESCE(v_current_score, 5.00);
  IF p_adjustment_type = 'BONUS' THEN
    v_multiplier := CASE
      WHEN v_current_score >= 8.5 THEN 0.1
      WHEN v_current_score >= 7 THEN 0.25
      WHEN v_current_score >= 5 THEN 0.5
      WHEN v_current_score >= 3 THEN 0.75
      ELSE 1
    END;
    v_new_score := LEAST(10.00, v_current_score + p_base_impact * v_multiplier);
  ELSE
    v_multiplier := CASE
      WHEN v_current_score < 1.5 THEN 0.1
      WHEN v_current_score < 3 THEN 0.25
      WHEN v_current_score < 5 THEN 0.5
      WHEN v_current_score < 7 THEN 0.75
      ELSE 1
    END;
    v_new_score := GREATEST(0.00, v_current_score - p_base_impact * v_multiplier);
  END IF;

  v_new_score := ROUND(v_new_score, 2);
  v_delta := v_new_score - v_current_score;
  v_classification := CASE
    WHEN v_new_score >= 8.5 THEN 'xuat_sac'
    WHEN v_new_score >= 7 THEN 'gioi'
    WHEN v_new_score >= 5 THEN 'kha'
    ELSE 'trung_binh_yeu'
  END;

  IF v_rate_id IS NULL THEN
    INSERT INTO public.subject_rates (
      student_id,
      classroom_id,
      subject_id,
      subject_name,
      score,
      classification
    )
    VALUES (
      p_student_id,
      p_classroom_id,
      p_subject_id,
      v_subject_name,
      v_new_score,
      v_classification
    )
    RETURNING id INTO v_rate_id;
  ELSE
    UPDATE public.subject_rates
    SET classroom_id = p_classroom_id,
        subject_id = p_subject_id,
        subject_name = v_subject_name,
        score = v_new_score,
        classification = v_classification,
        updated_at = now()
    WHERE id = v_rate_id;
  END IF;

  INSERT INTO public.subject_rate_transactions (
    student_id,
    classroom_id,
    subject_id,
    subject_name,
    adjustment_type,
    delta_score,
    previous_score,
    new_score,
    base_impact,
    reason,
    created_by,
    source_type
  )
  VALUES (
    p_student_id,
    p_classroom_id,
    p_subject_id,
    v_subject_name,
    p_adjustment_type,
    v_delta,
    v_current_score,
    v_new_score,
    p_base_impact,
    trim(p_reason),
    auth.uid(),
    'teacher_quick_action'
  )
  RETURNING to_jsonb(subject_rate_transactions.*)
  INTO v_transaction;

  RETURN v_transaction;
END;
$$;

REVOKE ALL ON FUNCTION public.apply_classroom_subject_rate_change(
  uuid, uuid, uuid, text, text, numeric, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.apply_classroom_subject_rate_change(
  uuid, uuid, uuid, text, text, numeric, text
) TO authenticated;

NOTIFY pgrst, 'reload schema';
