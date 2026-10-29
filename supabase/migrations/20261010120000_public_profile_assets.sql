INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-assets', 'profile-assets', true)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public;

GRANT SELECT ON public.profiles TO authenticated;

DROP POLICY IF EXISTS "Authenticated users can read profiles"
  ON public.profiles;
CREATE POLICY "Authenticated users can read profiles"
  ON public.profiles
  FOR SELECT TO authenticated
  USING (true);

NOTIFY pgrst, 'reload schema';
