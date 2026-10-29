CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text,
  class_name text,
  avatar_url text,
  banner_url text,
  bio text
);

CREATE TABLE IF NOT EXISTS public.user_inventory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  item_name text NOT NULL,
  item_type text NOT NULL,
  icon_url text,
  is_equipped boolean NOT NULL DEFAULT false
);

ALTER TABLE public.user_inventory
  DROP CONSTRAINT IF EXISTS user_inventory_item_type_check;
ALTER TABLE public.user_inventory
  ADD CONSTRAINT user_inventory_item_type_check
  CHECK (item_type IN ('badge', 'title', 'frame'));

CREATE INDEX IF NOT EXISTS user_inventory_user_equipped_idx
  ON public.user_inventory (user_id, is_equipped);

CREATE TABLE IF NOT EXISTS public.direct_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_one_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  participant_two_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT direct_conversations_distinct_participants
    CHECK (participant_one_id <> participant_two_id),
  CONSTRAINT direct_conversations_sorted_participants
    CHECK (participant_one_id < participant_two_id),
  CONSTRAINT direct_conversations_unique_pair
    UNIQUE (participant_one_id, participant_two_id)
);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'direct_conversations'
      AND column_name = 'conversation.participant_one_id'
  ) AND NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'direct_conversations'
      AND column_name = 'participant_one_id'
  ) THEN
    ALTER TABLE public.direct_conversations
      RENAME COLUMN "conversation.participant_one_id" TO participant_one_id;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'direct_conversations'
      AND column_name = 'participant_one_id'
  ) THEN
    ALTER TABLE public.direct_conversations
      ADD COLUMN participant_one_id uuid
      REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'direct_conversations'
      AND column_name = 'participant_two_id'
  ) THEN
    ALTER TABLE public.direct_conversations
      ADD COLUMN participant_two_id uuid
      REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.direct_conversations
    WHERE participant_one_id IS NULL
       OR participant_two_id IS NULL
  ) THEN
    RAISE EXCEPTION
      'Cannot repair direct_conversations automatically: participant IDs are missing';
  END IF;

  ALTER TABLE public.direct_conversations
    ALTER COLUMN participant_one_id SET NOT NULL,
    ALTER COLUMN participant_two_id SET NOT NULL;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.direct_conversations'::regclass
      AND conname = 'direct_conversations_participant_one_id_fkey'
  ) THEN
    ALTER TABLE public.direct_conversations
      ADD CONSTRAINT direct_conversations_participant_one_id_fkey
      FOREIGN KEY (participant_one_id)
      REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.direct_conversations'::regclass
      AND conname = 'direct_conversations_participant_two_id_fkey'
  ) THEN
    ALTER TABLE public.direct_conversations
      ADD CONSTRAINT direct_conversations_participant_two_id_fkey
      FOREIGN KEY (participant_two_id)
      REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.direct_conversations'::regclass
      AND contype = 'p'
  ) THEN
    ALTER TABLE public.direct_conversations
      ADD CONSTRAINT direct_conversations_pkey PRIMARY KEY (id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.direct_conversations'::regclass
      AND conname = 'direct_conversations_distinct_participants'
  ) THEN
    ALTER TABLE public.direct_conversations
      ADD CONSTRAINT direct_conversations_distinct_participants
      CHECK (participant_one_id <> participant_two_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.direct_conversations'::regclass
      AND conname = 'direct_conversations_sorted_participants'
  ) THEN
    ALTER TABLE public.direct_conversations
      ADD CONSTRAINT direct_conversations_sorted_participants
      CHECK (participant_one_id < participant_two_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.direct_conversations'::regclass
      AND conname = 'direct_conversations_unique_pair'
  ) THEN
    ALTER TABLE public.direct_conversations
      ADD CONSTRAINT direct_conversations_unique_pair
      UNIQUE (participant_one_id, participant_two_id);
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.direct_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL
    REFERENCES public.direct_conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL CHECK (length(trim(content)) > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS direct_messages_conversation_created_idx
  ON public.direct_messages (conversation_id, created_at);

ALTER TABLE public.direct_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_inventory ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT ON public.direct_conversations TO authenticated;
GRANT SELECT, INSERT ON public.direct_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT, UPDATE ON public.user_inventory TO authenticated;

DROP POLICY IF EXISTS "Users can create their own profile" ON public.profiles;
CREATE POLICY "Users can create their own profile"
  ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
  ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own inventory"
  ON public.user_inventory;
CREATE POLICY "Users can update their own inventory"
  ON public.user_inventory
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS direct_conversations_read_participants
  ON public.direct_conversations;
CREATE POLICY direct_conversations_read_participants
  ON public.direct_conversations
  FOR SELECT TO authenticated
  USING (auth.uid() IN (participant_one_id, participant_two_id));

DROP POLICY IF EXISTS direct_conversations_create_participant
  ON public.direct_conversations;
CREATE POLICY direct_conversations_create_participant
  ON public.direct_conversations
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() IN (participant_one_id, participant_two_id));

DROP POLICY IF EXISTS direct_messages_read_participants
  ON public.direct_messages;
CREATE POLICY direct_messages_read_participants
  ON public.direct_messages
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.direct_conversations AS conversation
      WHERE conversation.id = conversation_id
        AND auth.uid() IN (
          conversation.participant_one_id,
          conversation.participant_two_id
        )
    )
  );

DROP POLICY IF EXISTS direct_messages_create_by_participant
  ON public.direct_messages;
CREATE POLICY direct_messages_create_by_participant
  ON public.direct_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.direct_conversations AS conversation
      WHERE conversation.id = conversation_id
        AND auth.uid() IN (
          conversation.participant_one_id,
          conversation.participant_two_id
        )
    )
  );

DROP POLICY IF EXISTS "Authenticated users can read profiles"
  ON public.profiles;
CREATE POLICY "Authenticated users can read profiles"
  ON public.profiles
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Authenticated users can read equipped inventory"
  ON public.user_inventory;
CREATE POLICY "Authenticated users can read equipped inventory"
  ON public.user_inventory
  FOR SELECT TO authenticated
  USING (is_equipped OR user_id = auth.uid());

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'profiles'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'user_inventory'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.user_inventory;
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'direct_messages'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.direct_messages;
    END IF;
  END IF;
END;
$$;
