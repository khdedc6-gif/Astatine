CREATE OR REPLACE FUNCTION public.update_member_role(
  p_classroom_id uuid,
  p_target_user_id uuid,
  p_new_role_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF NOT public.is_classroom_staff(p_classroom_id) THEN
    RAISE EXCEPTION 'Only classroom staff can assign member roles'
      USING ERRCODE = '42501';
  END IF;

  IF p_new_role_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.classroom_roles AS role
    WHERE role.id = p_new_role_id
      AND role.classroom_id = p_classroom_id
  ) THEN
    RAISE EXCEPTION 'Role does not belong to this classroom';
  END IF;

  INSERT INTO public.classroom_members (
    classroom_id,
    user_id,
    role_in_class,
    custom_role_id
  )
  VALUES (
    p_classroom_id,
    p_target_user_id,
    'student',
    p_new_role_id
  )
  ON CONFLICT (classroom_id, user_id)
  DO UPDATE SET custom_role_id = EXCLUDED.custom_role_id;
END;
$$;

REVOKE ALL ON FUNCTION public.update_member_role(uuid, uuid, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_member_role(uuid, uuid, uuid)
  TO authenticated;
