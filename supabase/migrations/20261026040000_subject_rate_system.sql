-- Migration: Subject Rate System (0-5 scale, classification, bonuses, and penalties)
-- Project: Astatine

CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- 1. Create subject_rates table
CREATE TABLE IF NOT EXISTS public.subject_rates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  subject_name text NOT NULL,
  score numeric(4, 2) NOT NULL DEFAULT 0.00 CHECK (score >= 0.00 AND score <= 5.00),
  classification text NOT NULL DEFAULT 'trung_binh_yeu' 
    CHECK (classification IN ('trung_binh_yeu', 'kha', 'gioi', 'xuat_sac')),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT subject_rates_student_subject_unique UNIQUE (student_id, subject_name)
);
-- 2. Create subject_rate_transactions ledger for audit history
CREATE TABLE IF NOT EXISTS public.subject_rate_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  subject_name text NOT NULL,
  adjustment_type text NOT NULL CHECK (adjustment_type IN ('BONUS', 'PENALTY', 'SET')),
  delta_score numeric(4, 2) NOT NULL,
  previous_score numeric(4, 2) NOT NULL,
  new_score numeric(4, 2) NOT NULL,
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS subject_rates_student_id_idx ON public.subject_rates (student_id);
CREATE INDEX IF NOT EXISTS subject_rate_transactions_student_id_idx ON public.subject_rate_transactions (student_id);
-- 3. Enable RLS
ALTER TABLE public.subject_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subject_rate_transactions ENABLE ROW LEVEL SECURITY;
-- 4. RLS Policies
DROP POLICY IF EXISTS subject_rates_select_policy ON public.subject_rates;
CREATE POLICY subject_rates_select_policy ON public.subject_rates
  FOR SELECT TO authenticated
  USING (student_id = auth.uid() OR public.is_super_admin() OR EXISTS (
    SELECT 1 FROM public.class_members WHERE user_id = auth.uid() AND lower(role) IN ('teacher', 'owner')
  ));
DROP POLICY IF EXISTS subject_rate_transactions_select_policy ON public.subject_rate_transactions;
CREATE POLICY subject_rate_transactions_select_policy ON public.subject_rate_transactions
  FOR SELECT TO authenticated
  USING (student_id = auth.uid() OR public.is_super_admin() OR EXISTS (
    SELECT 1 FROM public.class_members WHERE user_id = auth.uid() AND lower(role) IN ('teacher', 'owner')
  ));
-- 5. Helper function to determine classification based on score (0-5 scale)
CREATE OR REPLACE FUNCTION public.calculate_subject_classification(p_score numeric)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_score < 2.0 THEN 'trung_binh_yeu'
    WHEN p_score < 3.5 THEN 'kha'
    WHEN p_score < 4.5 THEN 'gioi'
    ELSE 'xuat_sac'
  END;
$$;
-- 6. Core function to adjust subject rate (applying bonus or penalty rules)
CREATE OR REPLACE FUNCTION public.adjust_subject_rate(
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
  v_current_score numeric := 0.00;
  v_classification text := 'trung_binh_yeu';
  v_percentage numeric := 0.00;
  v_delta numeric := 0.00;
  v_new_score numeric := 0.00;
  v_reason text := '';
  v_is_penalty boolean := false;
BEGIN
  SELECT score, classification 
  INTO v_current_score, v_classification
  FROM public.subject_rates
  WHERE student_id = p_student_id AND subject_name = p_subject_name;

  IF NOT FOUND THEN
    v_current_score := 0.00;
    v_classification := 'trung_binh_yeu';
    INSERT INTO public.subject_rates (student_id, subject_name, score, classification)
    VALUES (p_student_id, p_subject_name, 0.00, 'trung_binh_yeu')
    ON CONFLICT (student_id, subject_name) DO NOTHING;
  END IF;

  v_percentage := CASE p_action_type
    WHEN 'XAY_DUNG_BAI' THEN CASE WHEN v_classification IN ('trung_binh_yeu', 'kha') THEN 2.0 ELSE 0.5 END
    WHEN 'GIAI_CHUYEN_DE' THEN CASE WHEN v_classification IN ('trung_binh_yeu', 'kha') THEN 20.0 ELSE 10.0 END
    WHEN 'THI_KHKT_TIN' THEN 20.0
    WHEN 'THANH_TICH_CAO' THEN 10.0
    WHEN 'NGOAI_KHOA' THEN 2.0
    WHEN 'HSG_NHAT' THEN CASE WHEN v_classification IN ('trung_binh_yeu', 'kha') THEN 30.0 ELSE 20.0 END
    WHEN 'HSG_NHI' THEN CASE WHEN v_classification IN ('trung_binh_yeu', 'kha') THEN 20.0 ELSE 10.0 END
    WHEN 'HSG_BA' THEN CASE WHEN v_classification IN ('trung_binh_yeu', 'kha') THEN 20.0 ELSE 10.0 END
    WHEN 'HSG_KK' THEN CASE WHEN v_classification IN ('trung_binh_yeu', 'kha') THEN 15.0 ELSE 5.0 END
    WHEN 'GIAN_LAN' THEN CASE WHEN v_classification IN ('trung_binh_yeu', 'kha') THEN 30.0 ELSE 50.0 END
    WHEN 'KHONG_HOAN_THANH_DU_AN' THEN CASE WHEN v_classification IN ('trung_binh_yeu', 'kha') THEN 20.0 ELSE 30.0 END
    WHEN 'KHONG_TUONG_TAC' THEN 5.0
    WHEN 'KHONG_NOP_BAI' THEN 15.0
    ELSE 0.0
  END;

  v_is_penalty := p_action_type IN ('GIAN_LAN', 'KHONG_HOAN_THANH_DU_AN', 'KHONG_TUONG_TAC', 'KHONG_NOP_BAI');

  v_reason := CASE p_action_type
    WHEN 'XAY_DUNG_BAI' THEN 'Xây dựng bài (+ ' || v_percentage || '%)'
    WHEN 'GIAI_CHUYEN_DE' THEN 'Giải chuyên đề (+ ' || v_percentage || '%)'
    WHEN 'THI_KHKT_TIN' THEN 'Tham gia cuộc thi KHKT/Tin học (+20%)'
    WHEN 'THANH_TICH_CAO' THEN 'Đạt thành tích cao môn (+10%)'
    WHEN 'NGOAI_KHOA' THEN 'Cuộc thi ngoại khóa (+2%)'
    WHEN 'HSG_NHAT' THEN 'Kỳ thi HSG - Giải Nhất (+ ' || v_percentage || '%)'
    WHEN 'HSG_NHI' THEN 'Kỳ thi HSG - Giải Nhì (+ ' || v_percentage || '%)'
    WHEN 'HSG_BA' THEN 'Kỳ thi HSG - Giải Ba (+ ' || v_percentage || '%)'
    WHEN 'HSG_KK' THEN 'Kỳ thi HSG - Khuyến khích (+ ' || v_percentage || '%)'
    WHEN 'GIAN_LAN' THEN 'Gian lận thi cử (- ' || v_percentage || '%)'
    WHEN 'KHONG_HOAN_THANH_DU_AN' THEN 'Không hoàn thành dự án (- ' || v_percentage || '%)'
    WHEN 'KHONG_TUONG_TAC' THEN 'Không tương tác trong các hoạt động nhóm (-5%)'
    WHEN 'KHONG_NOP_BAI' THEN 'Không nộp bài tập / bài kiểm tra kém (-15%)'
    ELSE COALESCE(p_custom_reason, 'Custom adjustment')
  END;

  v_delta := 5.0 * (v_percentage / 100.0);
  IF v_is_penalty THEN
    v_new_score := GREATEST(0.00, v_current_score - v_delta);
    v_delta := -v_delta;
  ELSE
    v_new_score := LEAST(5.00, v_current_score + v_delta);
  END IF;

  v_new_score := ROUND(v_new_score, 2);

  UPDATE public.subject_rates
  SET score = v_new_score,
      classification = public.calculate_subject_classification(v_new_score),
      updated_at = now()
  WHERE student_id = p_student_id AND subject_name = p_subject_name;

  INSERT INTO public.subject_rate_transactions (
    student_id, subject_name, adjustment_type, delta_score, previous_score, new_score, reason
  )
  VALUES (
    p_student_id, 
    p_subject_name, 
    CASE WHEN v_is_penalty THEN 'PENALTY' ELSE 'BONUS' END, 
    v_delta, 
    v_current_score, 
    v_new_score, 
    COALESCE(p_custom_reason, v_reason)
  );

  RETURN v_new_score;
END;
$$;
-- 7. Function to calculate overall student GPA
CREATE OR REPLACE FUNCTION public.get_student_gpa(p_student_id uuid)
RETURNS numeric
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT COALESCE(ROUND(AVG(score), 2), 0.00)
  FROM public.subject_rates
  WHERE student_id = p_student_id;
$$;
