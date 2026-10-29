INSERT INTO public.profiles (id, full_name)
SELECT
  auth_user.id,
  COALESCE(
    NULLIF(trim(app_user.full_name), ''),
    NULLIF(trim(auth_user.raw_user_meta_data ->> 'full_name'), '')
  )
FROM auth.users AS auth_user
LEFT JOIN public.users AS app_user ON app_user.id = auth_user.id
WHERE NULLIF(trim(app_user.full_name), '') IS NOT NULL
   OR NULLIF(trim(auth_user.raw_user_meta_data ->> 'full_name'), '') IS NOT NULL
ON CONFLICT (id) DO UPDATE
SET full_name = COALESCE(
  NULLIF(trim(public.profiles.full_name), ''),
  EXCLUDED.full_name
);

CREATE OR REPLACE FUNCTION public.sync_auth_user_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  display_name text := NULLIF(trim(NEW.raw_user_meta_data ->> 'full_name'), '');
BEGIN
  UPDATE public.users
  SET full_name = COALESCE(
        NULLIF(trim(full_name), ''),
        display_name
      ),
      role = COALESCE(
        NULLIF(trim(NEW.raw_user_meta_data ->> 'role'), ''),
        role
      )
  WHERE id = NEW.id;

  INSERT INTO public.profiles (id, full_name)
  VALUES (NEW.id, display_name)
  ON CONFLICT (id) DO UPDATE
  SET full_name = COALESCE(
    NULLIF(trim(public.profiles.full_name), ''),
    EXCLUDED.full_name
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_profile_sync ON auth.users;
CREATE TRIGGER on_auth_user_profile_sync
  AFTER INSERT OR UPDATE OF raw_user_meta_data ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.sync_auth_user_profile();

NOTIFY pgrst, 'reload schema';