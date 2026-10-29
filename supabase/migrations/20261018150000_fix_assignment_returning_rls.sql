DROP POLICY IF EXISTS assignments_read_visible_to_class
  ON public.assignments;
CREATE POLICY assignments_read_visible_to_class
  ON public.assignments
  FOR SELECT TO authenticated
  USING (
    teacher_id = auth.uid()
    OR public.can_access_assignment(id)
  );
