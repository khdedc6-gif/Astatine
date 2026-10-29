CREATE OR REPLACE FUNCTION public.guard_classroom_member_role_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  authorized_change text;
BEGIN
  IF OLD.role_in_class IS DISTINCT FROM NEW.role_in_class THEN
    authorized_change := pg_catalog.current_setting(
      'app.authorized_member_role_change',
      true
    );

    IF auth.uid() IS NULL
      OR authorized_change IS DISTINCT FROM (
        auth.uid()::text || ':' ||
        NEW.classroom_id::text || ':' ||
        NEW.user_id::text
      )
    THEN
      RAISE EXCEPTION 'Change member role through the authorized RPC'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.guard_classroom_member_role_change()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS guard_classroom_member_role_change
  ON public.classroom_members;
CREATE TRIGGER guard_classroom_member_role_change
  BEFORE UPDATE OF role_in_class ON public.classroom_members
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_classroom_member_role_change();

CREATE OR REPLACE FUNCTION public.change_classroom_member_role(
  p_classroom_id uuid,
  p_target_user_id uuid,
  p_new_role_in_class text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  target_current_role text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required'
      USING ERRCODE = '42501';
  END IF;

  IF pg_catalog.lower(pg_catalog.btrim(p_new_role_in_class))
    NOT IN ('teacher', 'student')
  THEN
    RAISE EXCEPTION 'Role must be teacher or student'
      USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.classroom_members AS owner_membership
    WHERE owner_membership.classroom_id = p_classroom_id
      AND owner_membership.user_id = auth.uid()
      AND pg_catalog.lower(owner_membership.role_in_class) = 'owner'
  ) THEN
    RAISE EXCEPTION 'Only the classroom owner can change member roles'
      USING ERRCODE = '42501';
  END IF;

  SELECT pg_catalog.lower(target.role_in_class)
  INTO target_current_role
  FROM public.classroom_members AS target
  WHERE target.classroom_id = p_classroom_id
    AND target.user_id = p_target_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Classroom member not found'
      USING ERRCODE = 'P0002';
  END IF;

  IF target_current_role = 'owner' THEN
    RAISE EXCEPTION 'The classroom owner role cannot be changed here'
      USING ERRCODE = '42501';
  END IF;

  PERFORM pg_catalog.set_config(
    'app.authorized_member_role_change',
    auth.uid()::text || ':' || p_classroom_id::text || ':' ||
      p_target_user_id::text,
    true
  );

  UPDATE public.classroom_members
  SET role_in_class = pg_catalog.lower(pg_catalog.btrim(p_new_role_in_class))
  WHERE classroom_id = p_classroom_id
    AND user_id = p_target_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.change_classroom_member_role(
  uuid, uuid, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.change_classroom_member_role(
  uuid, uuid, text
) TO authenticated;
