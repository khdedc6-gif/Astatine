CREATE OR REPLACE FUNCTION public.can_read_profile(target_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT auth.uid() IS NOT NULL
    AND (
      target_user_id = auth.uid()
      OR EXISTS (
        SELECT 1
        FROM public.classroom_members AS viewer
        JOIN public.classroom_members AS target
          ON target.classroom_id = viewer.classroom_id
        WHERE viewer.user_id = auth.uid()
          AND target.user_id = target_user_id
      )
      OR EXISTS (
        SELECT 1
        FROM public.study_group_members AS viewer
        JOIN public.study_group_members AS target
          ON target.group_id = viewer.group_id
        WHERE viewer.user_id = auth.uid()
          AND viewer.status = 'accepted'
          AND target.user_id = target_user_id
          AND target.status = 'accepted'
      )
      OR EXISTS (
        SELECT 1
        FROM public.conversation_participants AS cp1
        JOIN public.conversation_participants AS cp2
          ON cp1.conversation_id = cp2.conversation_id
        WHERE cp1.user_id = auth.uid()
          AND cp2.user_id = target_user_id
      )
      OR EXISTS (
        SELECT 1
        FROM public.teacher_student_conversations AS conversation
        WHERE auth.uid() IN (
            conversation.student_id,
            conversation.teacher_id
          )
          AND target_user_id IN (
            conversation.student_id,
            conversation.teacher_id
          )
      )
    );
$$;

REVOKE ALL ON FUNCTION public.can_read_profile(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_read_profile(uuid) TO authenticated;

DROP POLICY IF EXISTS "Authenticated users can read profiles"
  ON public.profiles;
CREATE POLICY profiles_read_self_or_shared_group
  ON public.profiles
  FOR SELECT TO authenticated
  USING (public.can_read_profile(id));

DROP POLICY IF EXISTS daily_quests_read_authenticated
  ON public.daily_quests;
CREATE POLICY daily_quests_read_authenticated
  ON public.daily_quests
  FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL);
