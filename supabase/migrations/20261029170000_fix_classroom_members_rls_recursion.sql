CREATE OR REPLACE FUNCTION public.is_classroom_member(
  target_classroom_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.classroom_members AS member
    WHERE member.classroom_id = target_classroom_id
      AND member.user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.is_classroom_staff(
  target_classroom_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.classroom_members AS member
    LEFT JOIN public.users AS app_user ON app_user.id = member.user_id
    WHERE member.classroom_id = target_classroom_id
      AND member.user_id = auth.uid()
      AND (
        member.role_in_class IN ('owner', 'teacher')
        OR app_user.role IN ('teacher', 'developer')
      )
  );
$$;

REVOKE ALL ON FUNCTION public.is_classroom_member(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_classroom_member(uuid)
  TO authenticated;

REVOKE ALL ON FUNCTION public.is_classroom_staff(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_classroom_staff(uuid)
  TO authenticated;

DROP POLICY IF EXISTS astatine_classroom_members_assign_role
  ON public.classroom_members;
DROP POLICY IF EXISTS classroom_members_read_classmates
  ON public.classroom_members;
DROP POLICY IF EXISTS classroom_members_create_classroom_owner
  ON public.classroom_members;
DROP POLICY IF EXISTS classroom_members_add_members_by_staff
  ON public.classroom_members;
DROP POLICY IF EXISTS "Enable all operations for authenticated users on classroom_members"
  ON public.classroom_members;
DROP POLICY IF EXISTS "Secure classroom_members insert"
  ON public.classroom_members;
DROP POLICY IF EXISTS "Secure classroom_members update"
  ON public.classroom_members;
DROP POLICY IF EXISTS "allow role update"
  ON public.classroom_members;
DROP POLICY IF EXISTS classroom_members_read_authenticated
  ON public.classroom_members;
DROP POLICY IF EXISTS classroom_members_insert_owner
  ON public.classroom_members;
DROP POLICY IF EXISTS classroom_members_update_staff
  ON public.classroom_members;

CREATE POLICY classroom_members_read_authenticated
  ON public.classroom_members
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_classroom_member(classroom_id)
  );

CREATE POLICY classroom_members_insert_owner
  ON public.classroom_members
  FOR INSERT TO authenticated
  WITH CHECK (
    (
      user_id = auth.uid()
      AND lower(role_in_class) = 'owner'
      AND EXISTS (
        SELECT 1
        FROM public.classrooms AS classroom
        WHERE classroom.id = classroom_id
          AND classroom.created_by = auth.uid()
      )
    )
    OR (
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
    )
  );

CREATE POLICY classroom_members_update_staff
  ON public.classroom_members
  FOR UPDATE TO authenticated
  USING (public.is_classroom_staff(classroom_id))
  WITH CHECK (
    public.is_classroom_staff(classroom_id)
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
