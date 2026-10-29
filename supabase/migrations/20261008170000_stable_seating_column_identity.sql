ALTER TABLE public.classroom_seating_chart_seats
  ADD COLUMN IF NOT EXISTS seating_column_id uuid;

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

UPDATE public.classroom_seating_chart_seats AS seat
SET seating_column_id = seating_column.id
FROM public.classroom_seating_columns AS seating_column
WHERE seating_column.classroom_id = seat.classroom_id
  AND seating_column.column_index = seat.column_index
  AND seat.seating_column_id IS NULL;

ALTER TABLE public.classroom_seating_chart_seats
  ALTER COLUMN seating_column_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'classroom_seating_chart_seats_column_fk'
      AND conrelid = 'public.classroom_seating_chart_seats'::regclass
  ) THEN
    ALTER TABLE public.classroom_seating_chart_seats
      ADD CONSTRAINT classroom_seating_chart_seats_column_fk
      FOREIGN KEY (seating_column_id, classroom_id)
      REFERENCES public.classroom_seating_columns(id, classroom_id)
      ON DELETE CASCADE;
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS classroom_seating_chart_seats_column_idx
  ON public.classroom_seating_chart_seats (seating_column_id);

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
            WHERE seat.classroom_id =
                    classroom_seating_messages.classroom_id
              AND seat.student_id = auth.uid()
              AND seat.seating_column_id =
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
            WHERE seat.classroom_id =
                    classroom_seating_messages.classroom_id
              AND seat.student_id = auth.uid()
              AND seat.seating_column_id =
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
          column_id uuid,
          seat_index integer,
          student_id uuid
        )
      WHERE seat_data.row_index < 0
        OR seat_data.row_index >= p_row_count
        OR seat_data.seat_index NOT IN (0, 1)
        OR seat_data.student_id IS NULL
        OR NOT EXISTS (
          SELECT 1
          FROM public.classroom_seating_columns AS seating_column
          WHERE seating_column.id = seat_data.column_id
            AND seating_column.classroom_id = p_classroom_id
        )
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

  INSERT INTO public.classroom_seating_columns (
    classroom_id, column_index, name
  )
  SELECT p_classroom_id, column_data.column_index, trim(column_data.name)
  FROM jsonb_to_recordset(p_columns)
    AS column_data(column_index integer, name text)
  ON CONFLICT (classroom_id, column_index) DO UPDATE
  SET name = EXCLUDED.name;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(p_seats)
      AS seat_data(
        row_index integer,
        column_id uuid,
        seat_index integer,
        student_id uuid
      )
    JOIN public.classroom_seating_columns AS seating_column
      ON seating_column.id = seat_data.column_id
     AND seating_column.classroom_id = p_classroom_id
    WHERE seating_column.column_index >= p_column_count
  ) THEN
    RAISE EXCEPTION 'Seat assignments do not match the requested layout';
  END IF;

  DELETE FROM public.classroom_seating_chart_seats
  WHERE classroom_id = p_classroom_id;

  DELETE FROM public.classroom_seating_columns
  WHERE classroom_id = p_classroom_id
    AND column_index >= p_column_count;

  INSERT INTO public.classroom_seating_chart_seats (
    classroom_id,
    row_index,
    column_index,
    seat_index,
    student_id,
    seating_column_id
  )
  SELECT
    p_classroom_id,
    seat_data.row_index,
    seating_column.column_index,
    seat_data.seat_index,
    seat_data.student_id,
    seating_column.id
  FROM jsonb_to_recordset(p_seats)
    AS seat_data(
      row_index integer,
      column_id uuid,
      seat_index integer,
      student_id uuid
    )
  JOIN public.classroom_seating_columns AS seating_column
    ON seating_column.id = seat_data.column_id
   AND seating_column.classroom_id = p_classroom_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_classroom_seating_chart(
  uuid, integer, integer, jsonb, jsonb
) TO authenticated;
