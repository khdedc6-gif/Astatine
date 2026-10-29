ALTER TABLE public.user_wallets
  ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'user_wallets_version_nonnegative'
      AND conrelid = 'public.user_wallets'::regclass
  ) THEN
    ALTER TABLE public.user_wallets
      ADD CONSTRAINT user_wallets_version_nonnegative
      CHECK (version >= 0);
  END IF;
END;
$$;

NOTIFY pgrst, 'reload schema';
