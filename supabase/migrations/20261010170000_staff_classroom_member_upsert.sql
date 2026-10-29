DROP POLICY IF EXISTS classroom_members_add_members_by_staff
  ON public.classroom_members;
CREATE POLICY classroom_members_add_members_by_staff
  ON public.classroom_members
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_classroom_staff(classroom_id)
    AND lower(role_in_class) = 'student'
    AND (
      custom_role_id IS NULL
      OR EXISTS (
        SELECT 1
        FROM public.classroom_roles AS role
        WHERE role.id = custom_role_id
          AND role.classroom_id = classroom_members.classroom_id
      )
    )
  );
