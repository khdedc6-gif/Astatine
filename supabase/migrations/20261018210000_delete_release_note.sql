CREATE OR REPLACE FUNCTION public.admin_delete_release_note(
  p_release_note_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
BEGIN
  IF v_admin_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.users AS developer
    WHERE developer.id = v_admin_id
      AND developer.is_dev IS TRUE
  ) THEN
    RAISE EXCEPTION 'Developer access required';
  END IF;

  DELETE FROM public.app_release_notes
  WHERE id = p_release_note_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Release note not found';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_delete_release_note(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_release_note(uuid)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
