CREATE OR REPLACE FUNCTION public.is_legacy_class_member(
  target_class_id uuid
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
    FROM public.class_members AS member
    WHERE member.class_id = target_class_id
      AND member.user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.is_legacy_class_staff(
  target_class_id uuid
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
    FROM public.class_members AS member
    WHERE member.class_id = target_class_id
      AND member.user_id = auth.uid()
      AND member.role IN ('teacher', 'owner', 'assistant')
  );
$$;

REVOKE ALL ON FUNCTION public.is_legacy_class_member(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_legacy_class_member(uuid)
  TO authenticated;

REVOKE ALL ON FUNCTION public.is_legacy_class_staff(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_legacy_class_staff(uuid)
  TO authenticated;

DROP POLICY IF EXISTS class_members_select_policy
  ON public.class_members;
DROP POLICY IF EXISTS class_members_insert_policy
  ON public.class_members;
DROP POLICY IF EXISTS class_members_delete_policy
  ON public.class_members;

CREATE POLICY class_members_select_policy
  ON public.class_members
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_legacy_class_member(class_id)
  );

CREATE POLICY class_members_insert_policy
  ON public.class_members
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    OR public.is_legacy_class_staff(class_id)
  );

CREATE POLICY class_members_delete_policy
  ON public.class_members
  FOR DELETE TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_legacy_class_staff(class_id)
  );
