CREATE OR REPLACE FUNCTION public.is_current_user_dev()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users AS admin_user
    WHERE admin_user.id = (SELECT auth.uid())
      AND admin_user.is_dev IS TRUE
  );
$$;

REVOKE ALL ON FUNCTION public.is_current_user_dev() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_current_user_dev() TO authenticated;

CREATE TABLE IF NOT EXISTS public.app_branding_assets (
  id smallint PRIMARY KEY CHECK (id = 1),
  login_background_url text,
  overview_illustration_url text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES public.users(id) ON DELETE SET NULL
);

INSERT INTO public.app_branding_assets (id)
VALUES (1)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.app_branding_assets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_branding_assets_read_public
  ON public.app_branding_assets;
CREATE POLICY app_branding_assets_read_public
  ON public.app_branding_assets
  FOR SELECT TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS app_branding_assets_update_developer
  ON public.app_branding_assets;
CREATE POLICY app_branding_assets_update_developer
  ON public.app_branding_assets
  FOR UPDATE TO authenticated
  USING (id = 1 AND public.is_current_user_dev())
  WITH CHECK (id = 1 AND public.is_current_user_dev());

GRANT SELECT ON public.app_branding_assets TO anon, authenticated;
GRANT UPDATE ON public.app_branding_assets TO authenticated;

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'app-branding-assets',
  'app-branding-assets',
  true,
  8388608,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS app_branding_assets_read_storage_developer
  ON storage.objects;
CREATE POLICY app_branding_assets_read_storage_developer
  ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'app-branding-assets'
    AND name IN ('login-background', 'overview-illustration')
    AND public.is_current_user_dev()
  );

DROP POLICY IF EXISTS app_branding_assets_insert_storage_developer
  ON storage.objects;
CREATE POLICY app_branding_assets_insert_storage_developer
  ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'app-branding-assets'
    AND name IN ('login-background', 'overview-illustration')
    AND public.is_current_user_dev()
  );

DROP POLICY IF EXISTS app_branding_assets_update_storage_developer
  ON storage.objects;
CREATE POLICY app_branding_assets_update_storage_developer
  ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'app-branding-assets'
    AND name IN ('login-background', 'overview-illustration')
    AND public.is_current_user_dev()
  )
  WITH CHECK (
    bucket_id = 'app-branding-assets'
    AND name IN ('login-background', 'overview-illustration')
    AND public.is_current_user_dev()
  );
