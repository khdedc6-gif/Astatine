CREATE OR REPLACE FUNCTION public.can_manage_classroom_assignments(
  target_classroom_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT auth.uid() IS NOT NULL
    AND (
      EXISTS (
        SELECT 1
        FROM public.users AS app_user
        WHERE app_user.id = auth.uid()
          AND pg_catalog.lower(app_user.role) IN ('teacher', 'developer')
      )
      OR EXISTS (
        SELECT 1
        FROM public.classroom_members AS member
        WHERE member.classroom_id = target_classroom_id
          AND member.user_id = auth.uid()
          AND pg_catalog.lower(member.role_in_class) IN ('owner', 'teacher')
      )
    );
$$;

REVOKE ALL ON FUNCTION public.can_manage_classroom_assignments(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_manage_classroom_assignments(uuid)
  TO authenticated;

DROP POLICY IF EXISTS assignments_create_by_classroom_staff
  ON public.assignments;
CREATE POLICY assignments_create_by_classroom_staff
  ON public.assignments
  FOR INSERT TO authenticated
  WITH CHECK (
    teacher_id = auth.uid()
    AND public.can_manage_classroom_assignments(class_id)
  );

DROP POLICY IF EXISTS assignments_update_by_teacher
  ON public.assignments;
CREATE POLICY assignments_update_by_teacher
  ON public.assignments
  FOR UPDATE TO authenticated
  USING (
    teacher_id = auth.uid()
    AND public.can_manage_classroom_assignments(class_id)
  )
  WITH CHECK (
    teacher_id = auth.uid()
    AND public.can_manage_classroom_assignments(class_id)
  );

DROP POLICY IF EXISTS questions_manage_by_assignment_teacher
  ON public.questions;
CREATE POLICY questions_manage_by_assignment_teacher
  ON public.questions
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.assignments AS assignment
      WHERE assignment.id = questions.assignment_id
        AND assignment.teacher_id = auth.uid()
        AND public.can_manage_classroom_assignments(assignment.class_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.assignments AS assignment
      WHERE assignment.id = questions.assignment_id
        AND assignment.teacher_id = auth.uid()
        AND public.can_manage_classroom_assignments(assignment.class_id)
    )
  );
