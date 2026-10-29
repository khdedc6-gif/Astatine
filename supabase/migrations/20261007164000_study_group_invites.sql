CREATE TABLE IF NOT EXISTS public.study_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  classroom_id uuid NOT NULL REFERENCES public.classrooms(id) ON DELETE CASCADE,
  class_name text NOT NULL,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  group_name text NOT NULL,
  subject text NOT NULL,
  topic text NOT NULL,
  deadline text NOT NULL,
  task_assignments jsonb NOT NULL DEFAULT '[]'::jsonb,
  ai_detection_enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.study_group_members (
  group_id uuid NOT NULL
    REFERENCES public.study_groups(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invited_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at timestamptz NOT NULL DEFAULT now(),
  accepted_at timestamptz,
  PRIMARY KEY (group_id, user_id)
);

CREATE INDEX IF NOT EXISTS study_group_members_user_status_idx
  ON public.study_group_members (user_id, status);

ALTER TABLE public.study_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_group_members ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.can_read_study_group(target_group_id uuid)
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
      AND membership.status IN ('pending', 'accepted')
  );
$$;

REVOKE ALL ON FUNCTION public.can_read_study_group(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_read_study_group(uuid) TO authenticated;

DROP POLICY IF EXISTS study_groups_read_members
  ON public.study_groups;
CREATE POLICY study_groups_read_members
  ON public.study_groups
  FOR SELECT TO authenticated
  USING (public.can_read_study_group(id));

DROP POLICY IF EXISTS study_group_members_read_group
  ON public.study_group_members;
CREATE POLICY study_group_members_read_group
  ON public.study_group_members
  FOR SELECT TO authenticated
  USING (public.can_read_study_group(group_id));

CREATE OR REPLACE FUNCTION public.create_study_group(
  p_classroom_id uuid,
  p_group_name text,
  p_class_name text,
  p_subject text,
  p_topic text,
  p_deadline text,
  p_ai_detection_enabled boolean,
  p_invited_user_ids uuid[],
  p_task_assignments jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_user_id uuid := auth.uid();
  created_group_id uuid;
  invited_user_id uuid;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication is required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.classroom_members AS membership
    WHERE membership.classroom_id = p_classroom_id
      AND membership.user_id = current_user_id
  ) THEN
    RAISE EXCEPTION 'You must be a member of the selected classroom';
  END IF;

  IF p_group_name IS NULL OR btrim(p_group_name) = ''
     OR p_subject IS NULL OR btrim(p_subject) = ''
     OR p_topic IS NULL OR btrim(p_topic) = ''
     OR p_deadline IS NULL OR btrim(p_deadline) = '' THEN
    RAISE EXCEPTION 'Group details are incomplete';
  END IF;

  IF p_task_assignments IS NULL OR jsonb_typeof(p_task_assignments) <> 'array' THEN
    RAISE EXCEPTION 'Task assignments must be an array';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_task_assignments) AS assignment
    WHERE assignment->>'assignee_user_id' IS NOT NULL
      AND assignment->>'assignee_user_id' <> current_user_id::text
      AND NOT EXISTS (
        SELECT 1
        FROM unnest(COALESCE(p_invited_user_ids, ARRAY[]::uuid[]))
          AS invitee(user_id)
        WHERE invitee.user_id::text = assignment->>'assignee_user_id'
      )
  ) THEN
    RAISE EXCEPTION 'Task assignees must be members of the group';
  END IF;

  FOREACH invited_user_id IN ARRAY COALESCE(p_invited_user_ids, ARRAY[]::uuid[])
  LOOP
    IF invited_user_id = current_user_id OR NOT EXISTS (
      SELECT 1
      FROM public.classroom_members AS membership
      WHERE membership.classroom_id = p_classroom_id
        AND membership.user_id = invited_user_id
    ) THEN
      RAISE EXCEPTION 'Every invitee must be a different member of the selected classroom';
    END IF;
  END LOOP;

  INSERT INTO public.study_groups (
    classroom_id,
    class_name,
    created_by,
    group_name,
    subject,
    topic,
    deadline,
    task_assignments,
    ai_detection_enabled
  )
  VALUES (
    p_classroom_id,
    btrim(p_class_name),
    current_user_id,
    btrim(p_group_name),
    btrim(p_subject),
    btrim(p_topic),
    btrim(p_deadline),
    p_task_assignments,
    COALESCE(p_ai_detection_enabled, true)
  )
  RETURNING id INTO created_group_id;

  INSERT INTO public.study_group_members (
    group_id, user_id, invited_by, status, accepted_at
  )
  VALUES (
    created_group_id, current_user_id, current_user_id, 'accepted', now()
  );

  INSERT INTO public.study_group_members (group_id, user_id, invited_by, status)
  SELECT created_group_id, invitee_id, current_user_id, 'pending'
  FROM (
    SELECT DISTINCT unnest(COALESCE(p_invited_user_ids, ARRAY[]::uuid[]))
      AS invitee_id
  ) AS invitees;

  RETURN created_group_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_study_group(
  uuid, text, text, text, text, text, boolean, uuid[], jsonb
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_study_group(
  uuid, text, text, text, text, text, boolean, uuid[], jsonb
) TO authenticated;

GRANT SELECT ON public.study_groups, public.study_group_members TO authenticated;

CREATE OR REPLACE FUNCTION public.respond_to_study_group_invite(
  p_group_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_status IS NULL OR p_status NOT IN ('accepted', 'declined') THEN
    RAISE EXCEPTION 'Invalid invitation response';
  END IF;

  UPDATE public.study_group_members
  SET status = p_status,
      accepted_at = CASE WHEN p_status = 'accepted' THEN now() ELSE NULL END
  WHERE group_id = p_group_id
    AND user_id = auth.uid()
    AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pending invitation not found';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.respond_to_study_group_invite(uuid, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.respond_to_study_group_invite(uuid, text)
  TO authenticated;
