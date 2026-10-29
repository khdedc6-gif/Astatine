CREATE TABLE IF NOT EXISTS public.teacher_student_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  classroom_id uuid NOT NULL REFERENCES public.classrooms(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  teacher_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT teacher_student_conversations_participants_differ
    CHECK (student_id <> teacher_id),
  CONSTRAINT teacher_student_conversations_unique_participants
    UNIQUE (classroom_id, student_id, teacher_id)
);

CREATE INDEX IF NOT EXISTS teacher_student_conversations_student_idx
  ON public.teacher_student_conversations (student_id, created_at DESC);

CREATE INDEX IF NOT EXISTS teacher_student_conversations_teacher_idx
  ON public.teacher_student_conversations (teacher_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.teacher_student_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL
    REFERENCES public.teacher_student_conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content text NOT NULL CHECK (length(trim(content)) > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS teacher_student_messages_conversation_created_idx
  ON public.teacher_student_messages (conversation_id, created_at);

CREATE OR REPLACE FUNCTION public.can_access_teacher_student_conversation(
  target_classroom_id uuid,
  target_student_id uuid,
  target_teacher_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    target_student_id <> target_teacher_id
    AND auth.uid() IN (target_student_id, target_teacher_id)
    AND EXISTS (
      SELECT 1
      FROM public.classroom_members AS student_membership
      WHERE student_membership.classroom_id = target_classroom_id
        AND student_membership.user_id = target_student_id
        AND lower(student_membership.role_in_class) NOT IN ('teacher', 'owner')
    )
    AND EXISTS (
      SELECT 1
      FROM public.assignments AS assignment
      WHERE assignment.class_id = target_classroom_id
        AND assignment.teacher_id = target_teacher_id
    );
$$;

REVOKE ALL ON FUNCTION public.can_access_teacher_student_conversation(
  uuid,
  uuid,
  uuid
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_access_teacher_student_conversation(
  uuid,
  uuid,
  uuid
) TO authenticated;

ALTER TABLE public.teacher_student_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_student_messages ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT ON public.teacher_student_conversations TO authenticated;
GRANT SELECT, INSERT ON public.teacher_student_messages TO authenticated;

DROP POLICY IF EXISTS teacher_student_conversations_read_participants
  ON public.teacher_student_conversations;
CREATE POLICY teacher_student_conversations_read_participants
  ON public.teacher_student_conversations
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() IN (student_id, teacher_id)
    AND public.can_access_teacher_student_conversation(
      classroom_id,
      student_id,
      teacher_id
    )
  );

DROP POLICY IF EXISTS teacher_student_conversations_create_by_student
  ON public.teacher_student_conversations;
CREATE POLICY teacher_student_conversations_create_by_student
  ON public.teacher_student_conversations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    student_id = auth.uid()
    AND public.can_access_teacher_student_conversation(
      classroom_id,
      student_id,
      teacher_id
    )
  );

DROP POLICY IF EXISTS teacher_student_messages_read_participants
  ON public.teacher_student_messages;
CREATE POLICY teacher_student_messages_read_participants
  ON public.teacher_student_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.teacher_student_conversations AS conversation
      WHERE conversation.id = conversation_id
        AND auth.uid() IN (conversation.student_id, conversation.teacher_id)
        AND public.can_access_teacher_student_conversation(
          conversation.classroom_id,
          conversation.student_id,
          conversation.teacher_id
        )
    )
  );

DROP POLICY IF EXISTS teacher_student_messages_create_by_participant
  ON public.teacher_student_messages;
CREATE POLICY teacher_student_messages_create_by_participant
  ON public.teacher_student_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.teacher_student_conversations AS conversation
      WHERE conversation.id = conversation_id
        AND auth.uid() IN (conversation.student_id, conversation.teacher_id)
        AND public.can_access_teacher_student_conversation(
          conversation.classroom_id,
          conversation.student_id,
          conversation.teacher_id
        )
    )
  );

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'teacher_student_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.teacher_student_messages;
  END IF;
END;
$$;
