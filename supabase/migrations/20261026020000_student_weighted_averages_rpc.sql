-- Migration: Add coefficient to subject_scores and create get_student_weighted_averages RPC function
-- Project: Astatine

ALTER TABLE public.subject_scores 
ADD COLUMN IF NOT EXISTS coefficient numeric(3, 2) NOT NULL DEFAULT 1.0 CHECK (coefficient > 0);
CREATE OR REPLACE FUNCTION public.get_student_weighted_averages(p_user_id uuid, p_class_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_object_agg(
    subject_name,
    jsonb_build_object(
      'weighted_average', ROUND(
        CASE WHEN SUM(coefficient) > 0 
             THEN SUM(score * coefficient) / SUM(coefficient)
             ELSE 0 END, 
        2
      ),
      'total_coefficient', SUM(coefficient),
      'scores_count', COUNT(*),
      'scores', jsonb_agg(
        jsonb_build_object(
          'id', id,
          'score', score,
          'coefficient', coefficient,
          'max_score', max_score,
          'created_at', created_at
        ) ORDER BY created_at DESC
      )
    )
  )
  INTO result
  FROM public.subject_scores
  WHERE user_id = p_user_id
    AND (p_class_id IS NULL OR class_id = p_class_id);

  RETURN COALESCE(result, '{}'::jsonb);
END;
$$;
