DO $$
DECLARE
  table_name text;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    FOREACH table_name IN ARRAY ARRAY[
      'classroom_seating_chart_seats',
      'classroom_seating_columns'
    ]
    LOOP
      IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = table_name
      ) THEN
        EXECUTE format(
          'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
          table_name
        );
      END IF;
    END LOOP;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_classroom_seating_student(
  p_classroom_id uuid,
  p_seating_column_id uuid,
  p_row_index integer,
  p_seat_index integer,
  p_student_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  IF p_row_index < 0 OR p_seat_index NOT IN (0, 1) THEN
    RAISE EXCEPTION 'Invalid seat position';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.classroom_members AS member
    WHERE member.classroom_id = p_classroom_id
      AND member.user_id = auth.uid()
      AND lower(member.role_in_class) IN ('owner', 'teacher')
  ) THEN
    RAISE EXCEPTION 'Only classroom staff can remove a student';
  END IF;

  DELETE FROM public.classroom_seating_chart_seats
  WHERE classroom_id = p_classroom_id
    AND seating_column_id = p_seating_column_id
    AND row_index = p_row_index
    AND seat_index = p_seat_index
    AND student_id = p_student_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Seat assignment no longer exists';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_classroom_seating_student(
  uuid, uuid, integer, integer, uuid
) TO authenticated;
