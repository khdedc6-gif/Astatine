CREATE TABLE IF NOT EXISTS public.app_release_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version text NOT NULL UNIQUE,
  released_at date NOT NULL DEFAULT CURRENT_DATE,
  features text NOT NULL DEFAULT '',
  improvements text NOT NULL DEFAULT '',
  fixes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES public.users(id) ON DELETE SET NULL
);

ALTER TABLE public.app_release_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_release_notes_read
  ON public.app_release_notes;
CREATE POLICY app_release_notes_read
  ON public.app_release_notes
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS app_release_notes_developer_insert
  ON public.app_release_notes;
CREATE POLICY app_release_notes_developer_insert
  ON public.app_release_notes
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.users AS developer
      WHERE developer.id = auth.uid()
        AND developer.is_dev IS TRUE
    )
  );

DROP POLICY IF EXISTS app_release_notes_developer_update
  ON public.app_release_notes;
CREATE POLICY app_release_notes_developer_update
  ON public.app_release_notes
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.users AS developer
      WHERE developer.id = auth.uid()
        AND developer.is_dev IS TRUE
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.users AS developer
      WHERE developer.id = auth.uid()
        AND developer.is_dev IS TRUE
    )
  );

GRANT SELECT, INSERT, UPDATE
  ON public.app_release_notes
  TO authenticated;

CREATE OR REPLACE FUNCTION public.set_app_release_notes_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at := now();
  NEW.updated_by := auth.uid();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS app_release_notes_set_updated_at
  ON public.app_release_notes;
CREATE TRIGGER app_release_notes_set_updated_at
  BEFORE UPDATE ON public.app_release_notes
  FOR EACH ROW
  EXECUTE FUNCTION public.set_app_release_notes_updated_at();

CREATE OR REPLACE FUNCTION public.admin_create_release_note()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_latest_parts text[];
  v_version text;
  v_note public.app_release_notes%ROWTYPE;
BEGIN
  IF v_admin_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.users AS developer
    WHERE developer.id = v_admin_id
      AND developer.is_dev IS TRUE
  ) THEN
    RAISE EXCEPTION 'Developer access required';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended('public.app_release_notes', 0)
  );

  SELECT regexp_match(
    version,
    '^v?([0-9]+)\.([0-9]+)\.([0-9]+)$'
  )
  INTO v_latest_parts
  FROM public.app_release_notes
  ORDER BY released_at DESC, created_at DESC
  LIMIT 1;

  IF v_latest_parts IS NULL THEN
    v_version := 'v1.0.0';
  ELSE
    v_version := format(
      'v%s.%s.%s',
      v_latest_parts[1],
      v_latest_parts[2],
      (v_latest_parts[3]::bigint + 1)::text
    );
  END IF;

  INSERT INTO public.app_release_notes (
    version,
    released_at,
    updated_by
  )
  VALUES (
    v_version,
    CURRENT_DATE,
    v_admin_id
  )
  RETURNING * INTO v_note;

  RETURN jsonb_build_object(
    'id', v_note.id,
    'version', v_note.version,
    'released_at', v_note.released_at,
    'features', v_note.features,
    'improvements', v_note.improvements,
    'fixes', v_note.fixes
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_create_release_note()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_create_release_note()
  TO authenticated;

NOTIFY pgrst, 'reload schema';
