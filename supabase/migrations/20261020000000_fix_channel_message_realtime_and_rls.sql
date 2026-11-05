-- Ensure channels and messages tables are added to Supabase Realtime publication
DO $$
DECLARE
  table_name text;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    FOREACH table_name IN ARRAY ARRAY[
      'channels',
      'messages'
    ]
    LOOP
      IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = table_name
      ) THEN
        EXECUTE format(
          'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
          table_name
        );
      END IF;
    END LOOP;
  END IF;
END;
$$;
-- Ensure RLS is enabled on channels and messages
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
-- Ensure robust channel read/visibility and message read/insert policies
DROP POLICY IF EXISTS channels_read_classroom_members ON public.channels;
CREATE POLICY channels_read_classroom_members
  ON public.channels
  AS PERMISSIVE
  FOR SELECT TO authenticated
  USING (
    public.is_classroom_member(classroom_id)
    OR EXISTS (
      SELECT 1 FROM public.classrooms AS c
      WHERE c.id = channels.classroom_id
        AND c.created_by = auth.uid()
    )
  );
DROP POLICY IF EXISTS messages_read_classroom_members ON public.messages;
CREATE POLICY messages_read_classroom_members
  ON public.messages
  AS PERMISSIVE
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.channels AS channel
      WHERE channel.id = messages.channel_id
        AND (
          public.is_classroom_member(channel.classroom_id)
          OR EXISTS (
            SELECT 1 FROM public.classrooms AS c
            WHERE c.id = channel.classroom_id
              AND c.created_by = auth.uid()
          )
        )
    )
  );
DROP POLICY IF EXISTS messages_insert_classroom_members ON public.messages;
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
        AND (
          public.is_classroom_member(channel.classroom_id)
          OR EXISTS (
            SELECT 1 FROM public.classrooms AS c
            WHERE c.id = channel.classroom_id
              AND c.created_by = auth.uid()
          )
        )
    )
  );
-- Grant appropriate permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.channels TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.messages TO authenticated;
