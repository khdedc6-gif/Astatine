CREATE OR REPLACE FUNCTION public.can_manage_classroom_channels(
  target_classroom_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
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
    OR EXISTS (
      SELECT 1
      FROM public.classroom_members AS member
      JOIN public.classroom_roles AS role
        ON role.id = member.custom_role_id
       AND role.classroom_id = member.classroom_id
      WHERE member.classroom_id = target_classroom_id
        AND member.user_id = auth.uid()
        AND role.can_manage_channels
    );
$$;

REVOKE ALL ON FUNCTION public.can_manage_classroom_channels(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_manage_classroom_channels(uuid)
  TO authenticated;

DROP POLICY IF EXISTS astatine_channels_role_manager_access
  ON public.channels;
CREATE POLICY astatine_channels_role_manager_access
  ON public.channels
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (public.can_manage_classroom_channels(classroom_id))
  WITH CHECK (public.can_manage_classroom_channels(classroom_id));
