ALTER FUNCTION public.can_read_study_group(uuid)
  SET search_path = '';

ALTER FUNCTION public.create_study_group(
  uuid, text, text, text, text, text, boolean, uuid[], jsonb
) SET search_path = '';

ALTER FUNCTION public.respond_to_study_group_invite(uuid, text)
  SET search_path = '';

ALTER FUNCTION public.is_accepted_study_group_member(uuid)
  SET search_path = '';

DROP POLICY IF EXISTS study_group_files_insert_self_accepted_member
  ON public.study_group_files;
CREATE POLICY study_group_files_insert_self_accepted_member
  ON public.study_group_files
  FOR INSERT TO authenticated
  WITH CHECK (
    uploaded_by = auth.uid()
    AND public.is_accepted_study_group_member(group_id)
    AND (
      assignee_user_id IS NULL
      OR EXISTS (
        SELECT 1
        FROM public.study_group_members AS assignee
        WHERE assignee.group_id = study_group_files.group_id
          AND assignee.user_id = study_group_files.assignee_user_id
          AND assignee.status = 'accepted'
      )
    )
    AND (storage.foldername(storage_path))[1] = group_id::text
    AND (storage.foldername(storage_path))[2] = auth.uid()::text
  );
