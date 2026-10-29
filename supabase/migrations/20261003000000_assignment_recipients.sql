CREATE TABLE IF NOT EXISTS public.assignment_recipients (
  assignment_id uuid NOT NULL REFERENCES public.assignments(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (assignment_id, student_id)
);

CREATE INDEX IF NOT EXISTS assignment_recipients_student_id_idx
  ON public.assignment_recipients (student_id);

ALTER TABLE public.assignment_recipients ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, DELETE ON public.assignment_recipients TO authenticated;

CREATE POLICY assignment_recipients_read_for_student_or_teacher
  ON public.assignment_recipients
  FOR SELECT
  TO authenticated
  USING (
    student_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.assignments AS assignment
      WHERE assignment.id = assignment_recipients.assignment_id
        AND assignment.teacher_id = auth.uid()
    )
  );

CREATE POLICY assignment_recipients_insert_by_assignment_teacher
  ON public.assignment_recipients
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.assignments AS assignment
      JOIN public.classroom_members AS member
        ON member.classroom_id = assignment.class_id
       AND member.user_id = assignment_recipients.student_id
      WHERE assignment.id = assignment_recipients.assignment_id
        AND assignment.teacher_id = auth.uid()
        AND lower(member.role_in_class) NOT IN ('teacher', 'owner')
    )
  );

CREATE POLICY assignment_recipients_delete_by_assignment_teacher
  ON public.assignment_recipients
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.assignments AS assignment
      WHERE assignment.id = assignment_recipients.assignment_id
        AND assignment.teacher_id = auth.uid()
    )
  );