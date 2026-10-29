CREATE OR REPLACE FUNCTION public.is_classroom_member(
  target_classroom_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.classroom_members AS member
    WHERE member.classroom_id = target_classroom_id
      AND member.user_id = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION public.is_classroom_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_classroom_member(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.can_access_assignment(
  target_assignment_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.assignments AS assignment
    WHERE assignment.id = target_assignment_id
      AND (
        assignment.teacher_id = auth.uid()
        OR (
          public.is_classroom_member(assignment.class_id)
          AND (
            lower(replace(COALESCE(assignment.assign_type, ''), '-', '_'))
              NOT IN (
                'individual',
                'student',
                'targeted',
                'direct',
                'selected_students',
                'specific_students'
              )
            OR EXISTS (
              SELECT 1
              FROM public.assignment_recipients AS recipient
              WHERE recipient.assignment_id = assignment.id
                AND recipient.student_id = auth.uid()
            )
          )
        )
      )
  );
$$;

REVOKE ALL ON FUNCTION public.can_access_assignment(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_access_assignment(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.join_classroom_by_code(p_code text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  current_user_id uuid := auth.uid();
  matched_classroom_id uuid;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT classroom.id
  INTO matched_classroom_id
  FROM public.classrooms AS classroom
  WHERE upper(trim(classroom.code)) = upper(trim(p_code))
  LIMIT 1;

  IF matched_classroom_id IS NULL THEN
    RAISE EXCEPTION 'Classroom code is invalid';
  END IF;

  INSERT INTO public.classroom_members (
    classroom_id,
    user_id,
    role_in_class
  )
  VALUES (matched_classroom_id, current_user_id, 'student')
  ON CONFLICT DO NOTHING;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Already joined' USING ERRCODE = '23505';
  END IF;

  RETURN matched_classroom_id;
END;
$$;

REVOKE ALL ON FUNCTION public.join_classroom_by_code(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_classroom_by_code(text)
  TO authenticated;

ALTER TABLE public.classrooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classroom_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classroom_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignment_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_quests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_quest_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_daily_progress ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.classrooms, public.classroom_members
  TO authenticated;
GRANT SELECT, INSERT, UPDATE
  ON public.classroom_roles
  TO authenticated;

DROP POLICY IF EXISTS classrooms_read_members
  ON public.classrooms;
CREATE POLICY classrooms_read_members
  ON public.classrooms
  FOR SELECT TO authenticated
  USING (
    created_by = auth.uid()
    OR public.is_classroom_member(id)
  );

DROP POLICY IF EXISTS classrooms_create_by_owner
  ON public.classrooms;
CREATE POLICY classrooms_create_by_owner
  ON public.classrooms
  FOR INSERT TO authenticated
  WITH CHECK (created_by = auth.uid());

DROP POLICY IF EXISTS classrooms_update_by_staff
  ON public.classrooms;
CREATE POLICY classrooms_update_by_staff
  ON public.classrooms
  FOR UPDATE TO authenticated
  USING (public.is_classroom_staff(id))
  WITH CHECK (public.is_classroom_staff(id));

DROP POLICY IF EXISTS classrooms_delete_by_staff
  ON public.classrooms;
CREATE POLICY classrooms_delete_by_staff
  ON public.classrooms
  FOR DELETE TO authenticated
  USING (public.is_classroom_staff(id));

DROP POLICY IF EXISTS classroom_members_read_classmates
  ON public.classroom_members;
CREATE POLICY classroom_members_read_classmates
  ON public.classroom_members
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_classroom_member(classroom_id)
  );

DROP POLICY IF EXISTS classroom_members_create_classroom_owner
  ON public.classroom_members;
CREATE POLICY classroom_members_create_classroom_owner
  ON public.classroom_members
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND lower(role_in_class) = 'owner'
    AND EXISTS (
      SELECT 1
      FROM public.classrooms AS classroom
      WHERE classroom.id = classroom_id
        AND classroom.created_by = auth.uid()
    )
  );

DROP POLICY IF EXISTS channels_read_classroom_members
  ON public.channels;
CREATE POLICY channels_read_classroom_members
  ON public.channels
  AS PERMISSIVE
  FOR SELECT TO authenticated
  USING (public.is_classroom_member(classroom_id));

DROP POLICY IF EXISTS messages_read_classroom_members
  ON public.messages;
CREATE POLICY messages_read_classroom_members
  ON public.messages
  AS PERMISSIVE
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.channels AS channel
      WHERE channel.id = messages.channel_id
        AND public.is_classroom_member(channel.classroom_id)
    )
  );

DROP POLICY IF EXISTS messages_insert_classroom_members
  ON public.messages;
CREATE POLICY messages_insert_classroom_members
  ON public.messages
  AS PERMISSIVE
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.channels AS channel
      WHERE channel.id = messages.channel_id
        AND public.is_classroom_member(channel.classroom_id)
    )
  );

GRANT SELECT, INSERT ON public.channels, public.messages TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.assignments, public.questions
  TO authenticated;
GRANT SELECT, INSERT, UPDATE
  ON public.assignment_submissions
  TO authenticated;
GRANT SELECT ON public.submissions TO authenticated;

DROP POLICY IF EXISTS assignments_read_visible_to_class
  ON public.assignments;
CREATE POLICY assignments_read_visible_to_class
  ON public.assignments
  FOR SELECT TO authenticated
  USING (public.can_access_assignment(id));

DROP POLICY IF EXISTS assignments_create_by_classroom_staff
  ON public.assignments;
CREATE POLICY assignments_create_by_classroom_staff
  ON public.assignments
  FOR INSERT TO authenticated
  WITH CHECK (
    teacher_id = auth.uid()
    AND public.is_classroom_staff(class_id)
  );

DROP POLICY IF EXISTS assignments_update_by_teacher
  ON public.assignments;
CREATE POLICY assignments_update_by_teacher
  ON public.assignments
  FOR UPDATE TO authenticated
  USING (teacher_id = auth.uid())
  WITH CHECK (
    teacher_id = auth.uid()
    AND public.is_classroom_staff(class_id)
  );

DROP POLICY IF EXISTS assignments_delete_by_teacher
  ON public.assignments;
CREATE POLICY assignments_delete_by_teacher
  ON public.assignments
  FOR DELETE TO authenticated
  USING (teacher_id = auth.uid());

DROP POLICY IF EXISTS questions_read_visible_assignment
  ON public.questions;
CREATE POLICY questions_read_visible_assignment
  ON public.questions
  FOR SELECT TO authenticated
  USING (public.can_access_assignment(assignment_id));

DROP POLICY IF EXISTS questions_manage_by_assignment_teacher
  ON public.questions;
CREATE POLICY questions_manage_by_assignment_teacher
  ON public.questions
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.assignments AS assignment
      WHERE assignment.id = questions.assignment_id
        AND assignment.teacher_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.assignments AS assignment
      WHERE assignment.id = questions.assignment_id
        AND assignment.teacher_id = auth.uid()
        AND public.is_classroom_staff(assignment.class_id)
    )
  );

DROP POLICY IF EXISTS assignment_submissions_read_student_or_teacher
  ON public.assignment_submissions;
CREATE POLICY assignment_submissions_read_student_or_teacher
  ON public.assignment_submissions
  FOR SELECT TO authenticated
  USING (
    student_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.assignments AS assignment
      WHERE assignment.id = assignment_submissions.assignment_id
        AND assignment.teacher_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS assignment_submissions_create_self
  ON public.assignment_submissions;
CREATE POLICY assignment_submissions_create_self
  ON public.assignment_submissions
  FOR INSERT TO authenticated
  WITH CHECK (
    student_id = auth.uid()
    AND public.can_access_assignment(assignment_id)
  );

DROP POLICY IF EXISTS assignment_submissions_update_self
  ON public.assignment_submissions;
CREATE POLICY assignment_submissions_update_self
  ON public.assignment_submissions
  FOR UPDATE TO authenticated
  USING (
    student_id = auth.uid()
    AND public.can_access_assignment(assignment_id)
  )
  WITH CHECK (
    student_id = auth.uid()
    AND public.can_access_assignment(assignment_id)
  );

DROP POLICY IF EXISTS submissions_read_student_or_teacher
  ON public.submissions;
CREATE POLICY submissions_read_student_or_teacher
  ON public.submissions
  FOR SELECT TO authenticated
  USING (
    student_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.assignments AS assignment
      WHERE assignment.id = submissions.assignment_id
        AND assignment.teacher_id = auth.uid()
    )
  );

GRANT SELECT ON public.daily_quests TO authenticated;
GRANT SELECT, INSERT ON public.user_quest_logs TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_daily_progress TO authenticated;

DROP POLICY IF EXISTS daily_quests_read_authenticated
  ON public.daily_quests;
CREATE POLICY daily_quests_read_authenticated
  ON public.daily_quests
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS user_quest_logs_read_self
  ON public.user_quest_logs;
CREATE POLICY user_quest_logs_read_self
  ON public.user_quest_logs
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS user_quest_logs_create_self
  ON public.user_quest_logs;
CREATE POLICY user_quest_logs_create_self
  ON public.user_quest_logs
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS user_daily_progress_read_self
  ON public.user_daily_progress;
CREATE POLICY user_daily_progress_read_self
  ON public.user_daily_progress
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS user_daily_progress_create_self
  ON public.user_daily_progress;
CREATE POLICY user_daily_progress_create_self
  ON public.user_daily_progress
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS user_daily_progress_update_self
  ON public.user_daily_progress;
CREATE POLICY user_daily_progress_update_self
  ON public.user_daily_progress
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS profile_assets_read_own_folder
  ON storage.objects;
CREATE POLICY profile_assets_read_own_folder
  ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'profile-assets'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS profile_assets_insert_own_folder
  ON storage.objects;
CREATE POLICY profile_assets_insert_own_folder
  ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'profile-assets'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS profile_assets_update_own_folder
  ON storage.objects;
CREATE POLICY profile_assets_update_own_folder
  ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'profile-assets'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'profile-assets'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

NOTIFY pgrst, 'reload schema';
