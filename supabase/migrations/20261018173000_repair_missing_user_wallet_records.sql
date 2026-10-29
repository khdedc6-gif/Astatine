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
LEFT JOIN public.users AS app_user ON app_user.id = auth_user.id
WHERE app_user.id IS NULL
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_wallets (user_id)
SELECT app_user.id
FROM public.users AS app_user
LEFT JOIN public.user_wallets AS wallet ON wallet.user_id = app_user.id
WHERE wallet.user_id IS NULL
ON CONFLICT (user_id) DO NOTHING;

NOTIFY pgrst, 'reload schema';
