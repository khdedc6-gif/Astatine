CREATE TABLE IF NOT EXISTS public.classroom_seating_charts (
  classroom_id uuid PRIMARY KEY
    REFERENCES public.classrooms(id) ON DELETE CASCADE,
  row_count integer NOT NULL DEFAULT 4 CHECK (row_count > 0),
  column_count integer NOT NULL DEFAULT 2 CHECK (column_count > 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.classroom_seating_columns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  classroom_id uuid NOT NULL
    REFERENCES public.classrooms(id) ON DELETE CASCADE,
  column_index integer NOT NULL CHECK (column_index >= 0),
  name text NOT NULL CHECK (length(trim(name)) > 0),
  UNIQUE (classroom_id, column_index),
  UNIQUE (id, classroom_id)
);

INSERT INTO public.classroom_seating_columns (
  classroom_id, column_index, name
)
SELECT
  chart.classroom_id,
  column_index,
  'Cột ' || (column_index + 1)::text
FROM public.classroom_seating_charts AS chart
CROSS JOIN LATERAL generate_series(0, chart.column_count - 1) AS column_index
ON CONFLICT (classroom_id, column_index) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.classroom_seating_chart_seats (
  classroom_id uuid NOT NULL
    REFERENCES public.classroom_seating_charts(classroom_id) ON DELETE CASCADE,
  row_index integer NOT NULL CHECK (row_index >= 0),
  column_index integer NOT NULL CHECK (column_index >= 0),
  seat_index integer NOT NULL CHECK (seat_index IN (0, 1)),
  student_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  PRIMARY KEY (classroom_id, row_index, column_index, seat_index),
  UNIQUE (classroom_id, student_id)
);

CREATE TABLE IF NOT EXISTS public.classroom_seating_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  classroom_id uuid NOT NULL,
  seating_column_id uuid NOT NULL,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL CHECK (length(trim(content)) > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT classroom_seating_messages_column_fk
    FOREIGN KEY (seating_column_id, classroom_id)
    REFERENCES public.classroom_seating_columns(id, classroom_id)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS classroom_seating_chart_seats_student_idx
  ON public.classroom_seating_chart_seats (student_id);
CREATE INDEX IF NOT EXISTS classroom_seating_messages_column_created_idx
  ON public.classroom_seating_messages (seating_column_id, created_at);

ALTER TABLE public.classroom_seating_charts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classroom_seating_columns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classroom_seating_chart_seats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classroom_seating_messages ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.classroom_seating_charts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.classroom_seating_columns TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.classroom_seating_chart_seats TO authenticated;
GRANT SELECT, INSERT ON public.classroom_seating_messages TO authenticated;

DROP POLICY IF EXISTS seating_charts_read_members
  ON public.classroom_seating_charts;
CREATE POLICY seating_charts_read_members
  ON public.classroom_seating_charts
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.classroom_members AS member
      WHERE member.classroom_id = classroom_seating_charts.classroom_id
        AND member.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS seating_charts_manage_staff
  ON public.classroom_seating_charts;
CREATE POLICY seating_charts_manage_staff
  ON public.classroom_seating_charts
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.classroom_members AS member
      WHERE member.classroom_id = classroom_seating_charts.classroom_id
        AND member.user_id = auth.uid()
        AND lower(member.role_in_class) IN ('owner', 'teacher')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.classroom_members AS member
      WHERE member.classroom_id = classroom_seating_charts.classroom_id
        AND member.user_id = auth.uid()
        AND lower(member.role_in_class) IN ('owner', 'teacher')
    )
  );

DROP POLICY IF EXISTS seating_columns_read_members
  ON public.classroom_seating_columns;
CREATE POLICY seating_columns_read_members
  ON public.classroom_seating_columns
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.classroom_members AS member
      WHERE member.classroom_id = classroom_seating_columns.classroom_id
        AND member.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS seating_columns_manage_staff
  ON public.classroom_seating_columns;
CREATE POLICY seating_columns_manage_staff
  ON public.classroom_seating_columns
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.classroom_members AS member
      WHERE member.classroom_id = classroom_seating_columns.classroom_id
        AND member.user_id = auth.uid()
        AND lower(member.role_in_class) IN ('owner', 'teacher')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.classroom_members AS member
      WHERE member.classroom_id = classroom_seating_columns.classroom_id
        AND member.user_id = auth.uid()
        AND lower(member.role_in_class) IN ('owner', 'teacher')
    )
  );

DROP POLICY IF EXISTS seating_chart_seats_read_members
  ON public.classroom_seating_chart_seats;
CREATE POLICY seating_chart_seats_read_members
  ON public.classroom_seating_chart_seats
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.classroom_members AS member
      WHERE member.classroom_id = classroom_seating_chart_seats.classroom_id
        AND member.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS seating_chart_seats_manage_staff
  ON public.classroom_seating_chart_seats;
CREATE POLICY seating_chart_seats_manage_staff
  ON public.classroom_seating_chart_seats
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.classroom_members AS member
      WHERE member.classroom_id = classroom_seating_chart_seats.classroom_id
        AND member.user_id = auth.uid()
        AND lower(member.role_in_class) IN ('owner', 'teacher')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.classroom_members AS member
      WHERE member.classroom_id = classroom_seating_chart_seats.classroom_id
        AND member.user_id = auth.uid()
        AND lower(member.role_in_class) IN ('owner', 'teacher')
    )
    AND EXISTS (
      SELECT 1 FROM public.classroom_members AS student
      WHERE student.classroom_id = classroom_seating_chart_seats.classroom_id
        AND student.user_id = classroom_seating_chart_seats.student_id
        AND lower(student.role_in_class) NOT IN ('owner', 'teacher')
    )
  );

DROP POLICY IF EXISTS seating_group_messages_read
  ON public.classroom_seating_messages;
CREATE POLICY seating_group_messages_read
  ON public.classroom_seating_messages
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.classroom_members AS member
      WHERE member.classroom_id = classroom_seating_messages.classroom_id
        AND member.user_id = auth.uid()
        AND (
          lower(member.role_in_class) IN ('owner', 'teacher')
          OR EXISTS (
            SELECT 1
            FROM public.classroom_seating_chart_seats AS seat
            JOIN public.classroom_seating_columns AS seating_column
              ON seating_column.classroom_id = seat.classroom_id
             AND seating_column.column_index = seat.column_index
            WHERE seat.classroom_id = classroom_seating_messages.classroom_id
              AND seat.student_id = auth.uid()
              AND seating_column.id =
                classroom_seating_messages.seating_column_id
          )
        )
    )
  );

DROP POLICY IF EXISTS seating_group_messages_insert
  ON public.classroom_seating_messages;
CREATE POLICY seating_group_messages_insert
  ON public.classroom_seating_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.classroom_members AS member
      WHERE member.classroom_id = classroom_seating_messages.classroom_id
        AND member.user_id = auth.uid()
        AND (
          lower(member.role_in_class) IN ('owner', 'teacher')
          OR EXISTS (
            SELECT 1
            FROM public.classroom_seating_chart_seats AS seat
            JOIN public.classroom_seating_columns AS seating_column
              ON seating_column.classroom_id = seat.classroom_id
             AND seating_column.column_index = seat.column_index
            WHERE seat.classroom_id = classroom_seating_messages.classroom_id
              AND seat.student_id = auth.uid()
              AND seating_column.id =
                classroom_seating_messages.seating_column_id
          )
        )
    )
  );

CREATE OR REPLACE FUNCTION public.save_classroom_seating_chart(
  p_classroom_id uuid,
  p_row_count integer,
  p_column_count integer,
  p_columns jsonb,
  p_seats jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  IF p_row_count < 1 OR p_column_count < 1 THEN
    RAISE EXCEPTION 'Rows and columns must be positive';
  END IF;

  IF jsonb_typeof(p_columns) <> 'array'
    OR jsonb_array_length(p_columns) <> p_column_count
  THEN
    RAISE EXCEPTION 'Column names must match the requested layout';
  END IF;

  IF jsonb_typeof(p_seats) <> 'array'
    OR EXISTS (
      SELECT 1
      FROM jsonb_to_recordset(p_seats)
        AS seat_data(
          row_index integer,
          column_index integer,
          seat_index integer,
          student_id uuid
        )
      WHERE seat_data.row_index < 0
        OR seat_data.row_index >= p_row_count
        OR seat_data.column_index < 0
        OR seat_data.column_index >= p_column_count
        OR seat_data.seat_index NOT IN (0, 1)
        OR seat_data.student_id IS NULL
    )
  THEN
    RAISE EXCEPTION 'Seat assignments do not match the requested layout';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.classroom_members AS member
    WHERE member.classroom_id = p_classroom_id
      AND member.user_id = auth.uid()
      AND lower(member.role_in_class) IN ('owner', 'teacher')
  ) THEN
    RAISE EXCEPTION 'Only classroom staff can edit the seating chart';
  END IF;

  INSERT INTO public.classroom_seating_charts (
    classroom_id, row_count, column_count, updated_at
  )
  VALUES (p_classroom_id, p_row_count, p_column_count, now())
  ON CONFLICT (classroom_id) DO UPDATE
  SET row_count = EXCLUDED.row_count,
      column_count = EXCLUDED.column_count,
      updated_at = now();

  DELETE FROM public.classroom_seating_chart_seats
  WHERE classroom_id = p_classroom_id;
  DELETE FROM public.classroom_seating_columns
  WHERE classroom_id = p_classroom_id
    AND column_index >= p_column_count;

  INSERT INTO public.classroom_seating_columns (
    classroom_id, column_index, name
  )
  SELECT p_classroom_id, column_data.column_index, trim(column_data.name)
  FROM jsonb_to_recordset(p_columns)
    AS column_data(column_index integer, name text)
  ON CONFLICT (classroom_id, column_index) DO UPDATE
  SET name = EXCLUDED.name;

  INSERT INTO public.classroom_seating_chart_seats (
    classroom_id, row_index, column_index, seat_index, student_id
  )
  SELECT
    p_classroom_id,
    seat_data.row_index,
    seat_data.column_index,
    seat_data.seat_index,
    seat_data.student_id
  FROM jsonb_to_recordset(p_seats)
    AS seat_data(
      row_index integer,
      column_index integer,
      seat_index integer,
      student_id uuid
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_classroom_seating_chart(
  uuid, integer, integer, jsonb, jsonb
) TO authenticated;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
    AND NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'classroom_seating_messages'
    )
  THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.classroom_seating_messages;
  END IF;
END;
$$;
