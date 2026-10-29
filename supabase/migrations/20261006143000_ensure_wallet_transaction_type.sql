ALTER TABLE public.wallet_transactions
  ADD COLUMN IF NOT EXISTS type varchar(30);

ALTER TABLE public.wallet_transactions
  ALTER COLUMN type DROP DEFAULT;

ALTER TABLE public.wallet_transactions
  ALTER COLUMN type TYPE varchar(30)
  USING type::text;

UPDATE public.wallet_transactions
SET type = COALESCE(
  NULLIF(type, ''),
  NULLIF(transaction_type::text, ''),
  'REWARD'
)
WHERE type IS NULL OR type = '';

ALTER TABLE public.wallet_transactions
  ALTER COLUMN type SET DEFAULT 'REWARD',
  ALTER COLUMN type SET NOT NULL;

NOTIFY pgrst, 'reload schema';
