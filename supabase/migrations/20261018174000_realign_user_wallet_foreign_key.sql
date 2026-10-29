INSERT INTO public.users (id, username, email, full_name)
SELECT
  auth_user.id,
  left(
    COALESCE(
      NULLIF(trim(auth_user.raw_user_meta_data ->> 'username'), ''),
      'user'
    ),
    13
  ) || '_' || replace(auth_user.id::text, '-', ''),
  COALESCE(
    NULLIF(trim(auth_user.email), ''),
    'user_' || auth_user.id::text || '@no-email.invalid'
  ),
  NULLIF(auth_user.raw_user_meta_data ->> 'full_name', '')
FROM auth.users AS auth_user
JOIN public.user_wallets AS wallet ON wallet.user_id = auth_user.id
LEFT JOIN public.users AS app_user ON app_user.id = auth_user.id
WHERE app_user.id IS NULL
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.user_wallets AS wallet
    LEFT JOIN public.users AS app_user ON app_user.id = wallet.user_id
    WHERE app_user.id IS NULL
  ) THEN
    RAISE EXCEPTION
      'Cannot realign user_wallets foreign key: wallet rows exist without matching public.users rows. Repair those user records first.';
  END IF;
END;
$$;

ALTER TABLE public.user_wallets
  DROP CONSTRAINT IF EXISTS user_wallets_user_id_fkey;

ALTER TABLE public.user_wallets
  ADD CONSTRAINT user_wallets_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES public.users(id)
  ON DELETE CASCADE;

NOTIFY pgrst, 'reload schema';
