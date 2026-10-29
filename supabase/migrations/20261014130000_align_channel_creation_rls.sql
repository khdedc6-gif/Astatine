DROP POLICY IF EXISTS astatine_channels_role_manager_access
  ON public.channels;
CREATE POLICY astatine_channels_role_manager_access
  ON public.channels
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (
    public.is_classroom_staff(classroom_id)
    OR EXISTS (
      SELECT 1
      FROM public.classroom_members AS member
      JOIN public.classroom_roles AS role
        ON role.id = member.custom_role_id
       AND role.classroom_id = member.classroom_id
      WHERE member.classroom_id = channels.classroom_id
        AND member.user_id = auth.uid()
        AND role.can_manage_channels
    )
  )
  WITH CHECK (
    public.is_classroom_staff(classroom_id)
    OR EXISTS (
      SELECT 1
      FROM public.classroom_members AS member
      JOIN public.classroom_roles AS role
        ON role.id = member.custom_role_id
       AND role.classroom_id = member.classroom_id
      WHERE member.classroom_id = channels.classroom_id
        AND member.user_id = auth.uid()
        AND role.can_manage_channels
    )
  );
