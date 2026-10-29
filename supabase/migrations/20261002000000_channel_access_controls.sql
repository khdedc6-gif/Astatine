ALTER TABLE public.channels
  ADD COLUMN IF NOT EXISTS target_role_ids uuid[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS chat_access text NOT NULL DEFAULT 'everyone',
  ADD COLUMN IF NOT EXISTS chat_role_ids uuid[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS is_hidden boolean NOT NULL DEFAULT false;

UPDATE public.channels
SET target_role_ids = ARRAY[target_role_id]
WHERE target_role_id IS NOT NULL
  AND cardinality(target_role_ids) = 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'channels_chat_access_check'
      AND conrelid = 'public.channels'::regclass
  ) THEN
    ALTER TABLE public.channels
      ADD CONSTRAINT channels_chat_access_check
      CHECK (chat_access IN ('everyone', 'roles', 'teachers'));
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS channels_target_role_ids_idx
  ON public.channels USING gin (target_role_ids);

CREATE INDEX IF NOT EXISTS channels_chat_role_ids_idx
  ON public.channels USING gin (chat_role_ids);

CREATE OR REPLACE FUNCTION public.is_classroom_staff(target_classroom_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.classroom_members AS member
    LEFT JOIN public.users AS app_user ON app_user.id = member.user_id
    WHERE member.classroom_id = target_classroom_id
      AND member.user_id = auth.uid()
      AND (
        member.role_in_class IN ('owner', 'teacher')
        OR app_user.role IN ('teacher', 'developer')
      )
  );
$$;

CREATE POLICY astatine_classroom_roles_member_read
  ON public.classroom_roles
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.classroom_members AS member
      WHERE member.classroom_id = classroom_roles.classroom_id
        AND member.user_id = auth.uid()
    )
  );

CREATE POLICY astatine_classroom_roles_staff_insert
  ON public.classroom_roles
  AS PERMISSIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_classroom_staff(classroom_id));

CREATE POLICY astatine_classroom_roles_staff_update
  ON public.classroom_roles
  AS PERMISSIVE
  FOR UPDATE
  TO authenticated
  USING (public.is_classroom_staff(classroom_id))
  WITH CHECK (public.is_classroom_staff(classroom_id));

CREATE POLICY astatine_classroom_members_assign_role
  ON public.classroom_members
  AS PERMISSIVE
  FOR UPDATE
  TO authenticated
  USING (public.is_classroom_staff(classroom_id))
  WITH CHECK (
    public.is_classroom_staff(classroom_id)
    AND (
      custom_role_id IS NULL
      OR EXISTS (
        SELECT 1
        FROM public.classroom_roles AS role
        WHERE role.id = custom_role_id
          AND role.classroom_id = classroom_members.classroom_id
      )
    )
  );

CREATE POLICY astatine_channels_role_visibility
  ON public.channels
  AS RESTRICTIVE
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.classroom_members AS member
      WHERE member.classroom_id = channels.classroom_id
        AND member.user_id = auth.uid()
        AND (
          (
            cardinality(channels.target_role_ids) = 0
            AND channels.target_role_id IS NULL
          )
          OR member.role_in_class IN ('owner', 'teacher')
          OR member.custom_role_id = ANY(channels.target_role_ids)
          OR member.custom_role_id = channels.target_role_id
          OR EXISTS (
            SELECT 1
            FROM public.classroom_roles AS role
            WHERE role.id = member.custom_role_id
              AND role.classroom_id = member.classroom_id
              AND role.can_manage_channels
          )
        )
        AND (NOT channels.is_hidden OR member.role_in_class IN ('owner', 'teacher'))
        AND (
          NOT channels.is_private
          OR member.role_in_class IN ('owner', 'teacher')
        )
        AND (
          channels.allowed_roles IS DISTINCT FROM 'teacher_only'
          OR member.role_in_class IN ('owner', 'teacher')
        )
    )
  );

CREATE POLICY astatine_channels_role_manage
  ON public.channels
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.classroom_members AS member
      WHERE member.classroom_id = channels.classroom_id
        AND member.user_id = auth.uid()
        AND (
          member.role_in_class IN ('owner', 'teacher')
          OR EXISTS (
            SELECT 1
            FROM public.classroom_roles AS role
            WHERE role.id = member.custom_role_id
              AND role.classroom_id = member.classroom_id
              AND role.can_manage_channels
          )
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.classroom_members AS member
      WHERE member.classroom_id = channels.classroom_id
        AND member.user_id = auth.uid()
        AND (
          member.role_in_class IN ('owner', 'teacher')
          OR EXISTS (
            SELECT 1
            FROM public.classroom_roles AS role
            WHERE role.id = member.custom_role_id
              AND role.classroom_id = member.classroom_id
              AND role.can_manage_channels
          )
        )
    )
  );

CREATE POLICY astatine_messages_role_read
  ON public.messages
  AS RESTRICTIVE
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.channels AS channel
      JOIN public.classroom_members AS member
        ON member.classroom_id = channel.classroom_id
       AND member.user_id = auth.uid()
      WHERE channel.id = messages.channel_id
        AND (
          (
            cardinality(channel.target_role_ids) = 0
            AND channel.target_role_id IS NULL
          )
          OR member.role_in_class IN ('owner', 'teacher')
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
        AND (NOT channel.is_hidden OR member.role_in_class IN ('owner', 'teacher'))
        AND (
          NOT channel.is_private
          OR member.role_in_class IN ('owner', 'teacher')
        )
        AND (
          channel.allowed_roles IS DISTINCT FROM 'teacher_only'
          OR member.role_in_class IN ('owner', 'teacher')
        )
    )
  );

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
        AND (NOT channel.is_hidden OR member.role_in_class IN ('owner', 'teacher'))
        AND (
          channel.chat_access = 'everyone'
          OR member.role_in_class IN ('owner', 'teacher')
          OR (
            channel.chat_access = 'roles'
            AND member.custom_role_id = ANY(channel.chat_role_ids)
          )
        )
    )
  );

CREATE POLICY astatine_channels_role_manager_access
  ON public.channels
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.classroom_members AS member
      WHERE member.classroom_id = channels.classroom_id
        AND member.user_id = auth.uid()
        AND (
          member.role_in_class IN ('owner', 'teacher')
          OR EXISTS (
            SELECT 1
            FROM public.classroom_roles AS role
            WHERE role.id = member.custom_role_id
              AND role.classroom_id = member.classroom_id
              AND role.can_manage_channels
          )
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.classroom_members AS member
      WHERE member.classroom_id = channels.classroom_id
        AND member.user_id = auth.uid()
        AND (
          member.role_in_class IN ('owner', 'teacher')
          OR EXISTS (
            SELECT 1
            FROM public.classroom_roles AS role
            WHERE role.id = member.custom_role_id
              AND role.classroom_id = member.classroom_id
              AND role.can_manage_channels
          )
        )
    )
  );

CREATE POLICY astatine_channels_role_delete
  ON public.channels
  AS RESTRICTIVE
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.classroom_members AS member
      WHERE member.classroom_id = channels.classroom_id
        AND member.user_id = auth.uid()
        AND (
          member.role_in_class IN ('owner', 'teacher')
          OR EXISTS (
            SELECT 1
            FROM public.classroom_roles AS role
            WHERE role.id = member.custom_role_id
              AND role.classroom_id = member.classroom_id
              AND role.can_manage_channels
          )
        )
    )
  );

CREATE OR REPLACE FUNCTION public.enforce_channel_hidden_teacher()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.is_hidden IS DISTINCT FROM OLD.is_hidden
    AND NOT EXISTS (
      SELECT 1
      FROM public.classroom_members AS member
      WHERE member.classroom_id = OLD.classroom_id
        AND member.user_id = auth.uid()
        AND member.role_in_class IN ('owner', 'teacher')
    ) THEN
    RAISE EXCEPTION 'Only classroom teachers can hide or reopen a channel'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER channels_hidden_teacher_only
  BEFORE UPDATE OF is_hidden ON public.channels
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_channel_hidden_teacher();