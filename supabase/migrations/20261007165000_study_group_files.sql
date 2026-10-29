INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('study-group-files', 'study-group-files', false, 52428800)
ON CONFLICT (id) DO UPDATE
SET public = false,
    file_size_limit = EXCLUDED.file_size_limit;

CREATE TABLE IF NOT EXISTS public.study_group_files (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL
    REFERENCES public.study_groups(id) ON DELETE CASCADE,
  uploaded_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assignee_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  storage_path text NOT NULL UNIQUE,
  file_name text NOT NULL,
  mime_type text,
  size_bytes bigint NOT NULL CHECK (size_bytes >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT study_group_files_nonempty_name
    CHECK (length(trim(file_name)) > 0)
);

ALTER TABLE public.study_group_files
  ADD COLUMN IF NOT EXISTS assignee_user_id uuid
    REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS study_group_files_group_created_idx
  ON public.study_group_files (group_id, created_at DESC);

CREATE INDEX IF NOT EXISTS study_group_files_assignee_idx
  ON public.study_group_files (group_id, assignee_user_id);

CREATE OR REPLACE FUNCTION public.is_accepted_study_group_member(
  target_group_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.study_group_members AS membership
    WHERE membership.group_id = target_group_id
      AND membership.user_id = auth.uid()
      AND membership.status = 'accepted'
  );
$$;

REVOKE ALL ON FUNCTION public.is_accepted_study_group_member(uuid)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_accepted_study_group_member(uuid)
  TO authenticated;

ALTER TABLE public.study_group_files ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS study_group_files_select_accepted_members
  ON public.study_group_files;
CREATE POLICY study_group_files_select_accepted_members
  ON public.study_group_files
  FOR SELECT TO authenticated
  USING (public.is_accepted_study_group_member(group_id));

DROP POLICY IF EXISTS study_group_files_insert_self_accepted_member
  ON public.study_group_files;
CREATE POLICY study_group_files_insert_self_accepted_member
  ON public.study_group_files
  FOR INSERT TO authenticated
  WITH CHECK (
    uploaded_by = auth.uid()
    AND public.is_accepted_study_group_member(group_id)
    AND (storage.foldername(storage_path))[1] = group_id::text
    AND (storage.foldername(storage_path))[2] = auth.uid()::text
  );

GRANT SELECT, INSERT ON public.study_group_files TO authenticated;

DROP POLICY IF EXISTS study_group_file_objects_select_accepted_members
  ON storage.objects;
CREATE POLICY study_group_file_objects_select_accepted_members
  ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'study-group-files'
    AND public.is_accepted_study_group_member(
      ((storage.foldername(name))[1])::uuid
    )
  );

DROP POLICY IF EXISTS study_group_file_objects_insert_self
  ON storage.objects;
CREATE POLICY study_group_file_objects_insert_self
  ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'study-group-files'
    AND public.is_accepted_study_group_member(
      ((storage.foldername(name))[1])::uuid
    )
    AND (storage.foldername(name))[2] = auth.uid()::text
    AND coalesce(array_length(storage.foldername(name), 1), 0) = 2
  );

DROP POLICY IF EXISTS study_group_file_objects_delete_self
  ON storage.objects;
CREATE POLICY study_group_file_objects_delete_self
  ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'study-group-files'
    AND public.is_accepted_study_group_member(
      ((storage.foldername(name))[1])::uuid
    )
    AND (storage.foldername(name))[2] = auth.uid()::text
    AND coalesce(array_length(storage.foldername(name), 1), 0) = 2
  );
