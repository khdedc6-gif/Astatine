CREATE TABLE IF NOT EXISTS public.user_rate_limit_events (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action text NOT NULL CHECK (action IN ('chat_message', 'ai_prompt')),
  occurred_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX IF NOT EXISTS user_rate_limit_events_user_action_time_idx
  ON public.user_rate_limit_events (user_id, action, occurred_at DESC);

ALTER TABLE public.user_rate_limit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_rate_limit_events FROM PUBLIC, anon, authenticated;

DROP POLICY IF EXISTS astatine_messages_role_write
  ON public.messages;
DROP INDEX IF EXISTS public.channels_chat_role_ids_idx;

CREATE OR REPLACE FUNCTION public.parse_chat_role_ids(value text)
RETURNS uuid[]
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  parsed jsonb;
  result uuid[];
BEGIN
  IF value IS NULL OR pg_catalog.btrim(value) = '' THEN
    RETURN '{}'::uuid[];
  END IF;

  parsed := value::jsonb;
  IF pg_catalog.jsonb_typeof(parsed) <> 'array' THEN
    RAISE EXCEPTION 'chat_role_ids must contain a JSON array'
      USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(
    pg_catalog.array_agg(item.value::uuid),
    '{}'::uuid[]
  )
  INTO result
  FROM pg_catalog.jsonb_array_elements_text(parsed) AS item(value);

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.parse_chat_role_ids(text)
  FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  column_type text;
BEGIN
  SELECT columns.udt_name
  INTO column_type
  FROM information_schema.columns AS columns
  WHERE columns.table_schema = 'public'
    AND columns.table_name = 'channels'
    AND columns.column_name = 'chat_role_ids';

  IF column_type = 'text' THEN
    ALTER TABLE public.channels
      ALTER COLUMN chat_role_ids DROP DEFAULT;
    ALTER TABLE public.channels
      ALTER COLUMN chat_role_ids TYPE uuid[]
      USING public.parse_chat_role_ids(chat_role_ids);
  ELSIF column_type IS NULL THEN
    RAISE EXCEPTION 'public.channels.chat_role_ids does not exist';
  ELSIF column_type <> '_uuid' THEN
    RAISE EXCEPTION
      'Unsupported public.channels.chat_role_ids type: %',
      column_type;
  END IF;
END;
$$;

UPDATE public.channels
SET chat_role_ids = '{}'::uuid[]
WHERE chat_role_ids IS NULL;

ALTER TABLE public.channels
  ALTER COLUMN chat_role_ids SET DEFAULT '{}'::uuid[],
  ALTER COLUMN chat_role_ids SET NOT NULL;

CREATE INDEX IF NOT EXISTS channels_chat_role_ids_idx
  ON public.channels USING gin (chat_role_ids);

DROP FUNCTION public.parse_chat_role_ids(text);

CREATE OR REPLACE FUNCTION public.consume_user_rate_limit(
  target_user_id uuid,
  requested_action text,
  request_limit integer,
  window_seconds integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  request_count integer;
  window_start timestamptz;
BEGIN
  IF target_user_id IS NULL
    OR requested_action NOT IN ('chat_message', 'ai_prompt')
    OR request_limit < 1
    OR window_seconds < 1
  THEN
    RAISE EXCEPTION 'Invalid rate limit request'
      USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      target_user_id::text || ':' || requested_action,
      0
    )
  );

  window_start := pg_catalog.clock_timestamp()
    - pg_catalog.make_interval(secs => window_seconds);

  DELETE FROM public.user_rate_limit_events AS event
  WHERE event.user_id = target_user_id
    AND event.action = requested_action
    AND event.occurred_at < window_start;

  SELECT pg_catalog.count(*)::integer
  INTO request_count
  FROM public.user_rate_limit_events AS event
  WHERE event.user_id = target_user_id
    AND event.action = requested_action
    AND event.occurred_at >= window_start;

  IF request_count >= request_limit THEN
    RAISE SQLSTATE 'PT429'
      USING MESSAGE = 'Rate limit exceeded';
  END IF;

  INSERT INTO public.user_rate_limit_events (user_id, action)
  VALUES (target_user_id, requested_action);
END;
$$;

REVOKE ALL ON FUNCTION public.consume_user_rate_limit(
  uuid, text, integer, integer
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_user_rate_limit(
  uuid, text, integer, integer
) TO service_role;

CREATE OR REPLACE FUNCTION public.enforce_chat_message_limits()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.sender_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Sender must match the authenticated user'
      USING ERRCODE = '42501';
  END IF;

  IF pg_catalog.char_length(pg_catalog.btrim(NEW.content)) = 0 THEN
    RAISE EXCEPTION 'Message cannot be empty'
      USING ERRCODE = '23514';
  END IF;

  IF pg_catalog.char_length(NEW.content) > 2000 THEN
    RAISE EXCEPTION 'Message exceeds the 2,000 character limit'
      USING ERRCODE = '23514';
  END IF;

  PERFORM public.consume_user_rate_limit(
    NEW.sender_id,
    'chat_message',
    5,
    10
  );

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_chat_message_limits()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS enforce_chat_message_limits
  ON public.messages;
CREATE TRIGGER enforce_chat_message_limits
  BEFORE INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.enforce_chat_message_limits();

DROP TRIGGER IF EXISTS enforce_chat_message_limits
  ON public.direct_messages;
CREATE TRIGGER enforce_chat_message_limits
  BEFORE INSERT ON public.direct_messages
  FOR EACH ROW EXECUTE FUNCTION public.enforce_chat_message_limits();

DROP TRIGGER IF EXISTS enforce_chat_message_limits
  ON public.teacher_student_messages;
CREATE TRIGGER enforce_chat_message_limits
  BEFORE INSERT ON public.teacher_student_messages
  FOR EACH ROW EXECUTE FUNCTION public.enforce_chat_message_limits();

DROP TRIGGER IF EXISTS enforce_chat_message_limits
  ON public.classroom_seating_messages;
CREATE TRIGGER enforce_chat_message_limits
  BEFORE INSERT ON public.classroom_seating_messages
  FOR EACH ROW EXECUTE FUNCTION public.enforce_chat_message_limits();

DROP POLICY IF EXISTS astatine_messages_role_write
  ON public.messages;
CREATE POLICY astatine_messages_role_write
  ON public.messages
  AS RESTRICTIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.channels AS channel
      JOIN public.classroom_members AS member
        ON member.classroom_id = channel.classroom_id
       AND member.user_id = auth.uid()
      WHERE channel.id = messages.channel_id
        AND (
          (
            pg_catalog.cardinality(channel.target_role_ids) = 0
            AND channel.target_role_id IS NULL
          )
          OR pg_catalog.lower(member.role_in_class) IN ('owner', 'teacher')
          OR public.is_classroom_staff(channel.classroom_id)
          OR member.custom_role_id = ANY(channel.target_role_ids)
          OR member.custom_role_id = channel.target_role_id
          OR EXISTS (
            SELECT 1
            FROM public.classroom_roles AS role
            WHERE role.id = member.custom_role_id
              AND role.classroom_id = member.classroom_id
              AND role.can_manage_channels
          )
        )
        AND (
          NOT channel.is_hidden
          OR pg_catalog.lower(member.role_in_class) IN ('owner', 'teacher')
          OR public.is_classroom_staff(channel.classroom_id)
        )
        AND (
          NOT channel.is_private
          OR pg_catalog.lower(member.role_in_class) IN ('owner', 'teacher')
          OR public.is_classroom_staff(channel.classroom_id)
        )
        AND (
          channel.allowed_roles IS DISTINCT FROM 'teacher_only'
          OR pg_catalog.lower(member.role_in_class) IN ('owner', 'teacher')
          OR public.is_classroom_staff(channel.classroom_id)
        )
        AND (
          channel.chat_access = 'everyone'
          OR pg_catalog.lower(member.role_in_class) IN ('owner', 'teacher')
          OR public.is_classroom_staff(channel.classroom_id)
          OR (
            channel.chat_access = 'roles'
            AND member.custom_role_id = ANY(channel.chat_role_ids)
          )
        )
    )
  );
