ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS subscription_tier varchar(20) NOT NULL DEFAULT 'FREE',
  ADD COLUMN IF NOT EXISTS subscription_expires_at timestamptz;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'users_subscription_tier_check'
      AND conrelid = 'public.users'::regclass
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_subscription_tier_check
      CHECK (subscription_tier IN ('FREE', 'PRO', 'ULTRA'));
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.purchase_subscription(
  p_plan_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_price numeric(18, 4);
  v_wallet public.user_wallets%ROWTYPE;
  v_current_tier varchar(20);
  v_current_expiry timestamptz;
  v_new_expiry timestamptz;
  v_balance_after numeric(18, 4);
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  CASE p_plan_code
    WHEN 'FREE' THEN v_price := 0;
    WHEN 'PRO' THEN v_price := 490;
    WHEN 'ULTRA' THEN v_price := 1190;
    ELSE
      RAISE EXCEPTION 'Unknown subscription plan: %', p_plan_code;
  END CASE;

  PERFORM 1
  FROM public.users
  WHERE id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User account not found';
  END IF;

  INSERT INTO public.user_wallets (user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT *
  INTO v_wallet
  FROM public.user_wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF v_wallet.wallet_status <> 'ACTIVE' THEN
    RAISE EXCEPTION 'Wallet is not active';
  END IF;

  IF v_wallet.ast_balance - v_wallet.ast_frozen < v_price THEN
    RAISE EXCEPTION 'Insufficient AST balance';
  END IF;

  SELECT subscription_tier, subscription_expires_at
  INTO v_current_tier, v_current_expiry
  FROM public.users
  WHERE id = v_user_id;

  IF p_plan_code = 'FREE' THEN
    v_new_expiry := NULL;
  ELSIF p_plan_code = v_current_tier
        AND v_current_expiry > now() THEN
    v_new_expiry := v_current_expiry + interval '1 month';
  ELSE
    v_new_expiry := now() + interval '1 month';
  END IF;

  v_balance_after := v_wallet.ast_balance - v_price;

  IF v_price > 0 THEN
    UPDATE public.user_wallets
    SET ast_balance = v_balance_after,
        version = version + 1
    WHERE user_id = v_user_id;

    INSERT INTO public.wallet_transactions (
      transaction_code,
      user_id,
      currency,
      amount,
      balance_before,
      balance_after,
      type,
      transaction_type,
      reference_type,
      reference_id,
      description,
      status
    )
    VALUES (
      'SUB-' || gen_random_uuid()::text,
      v_user_id,
      'AST',
      -v_price,
      v_wallet.ast_balance,
      v_balance_after,
      'SPEND_AST',
      'SPEND_AST',
      'SUBSCRIPTION',
      p_plan_code,
      'Purchased ' || p_plan_code || ' subscription',
      'SUCCESS'
    );
  END IF;

  UPDATE public.users
  SET subscription_tier = p_plan_code,
      subscription_expires_at = v_new_expiry
  WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'subscription_tier', p_plan_code,
    'subscription_expires_at', v_new_expiry,
    'ast_balance', v_balance_after::text
  );
END;
$$;

REVOKE ALL ON FUNCTION public.purchase_subscription(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.purchase_subscription(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.purchase_subscription(text) TO authenticated;

NOTIFY pgrst, 'reload schema';
