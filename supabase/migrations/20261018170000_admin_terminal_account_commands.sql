ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_dev boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_banned boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS banned_until timestamptz,
  ADD COLUMN IF NOT EXISTS ban_reason text;

CREATE TABLE IF NOT EXISTS public.app_runtime_settings (
  id smallint PRIMARY KEY CHECK (id = 1),
  maintenance_mode boolean NOT NULL DEFAULT false,
  maintenance_message text NOT NULL DEFAULT 'Hệ thống đang bảo trì khẩn cấp',
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES public.users(id) ON DELETE SET NULL
);

INSERT INTO public.app_runtime_settings (id)
VALUES (1)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.app_runtime_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_runtime_settings_read_status
  ON public.app_runtime_settings;
CREATE POLICY app_runtime_settings_read_status
  ON public.app_runtime_settings
  FOR SELECT TO anon, authenticated
  USING (true);

GRANT SELECT ON public.app_runtime_settings TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_ban_user(
  p_username text,
  p_banned_until timestamptz,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_target public.users%ROWTYPE;
BEGIN
  IF v_admin_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.users AS admin_user
    WHERE admin_user.id = v_admin_id
      AND admin_user.is_dev IS TRUE
  ) THEN
    RAISE EXCEPTION 'Developer access required';
  END IF;

  IF NULLIF(trim(p_reason), '') IS NULL THEN
    RAISE EXCEPTION 'Ban reason is required';
  END IF;

  IF p_banned_until IS NOT NULL AND p_banned_until <= now() THEN
    RAISE EXCEPTION 'Ban expiry must be in the future';
  END IF;

  SELECT app_user.*
  INTO v_target
  FROM public.users AS app_user
  WHERE lower(app_user.username) = lower(trim(p_username))
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Username not found: %', p_username;
  END IF;

  UPDATE public.users
  SET is_banned = true,
      banned_until = p_banned_until,
      ban_reason = trim(p_reason),
      updated_at = now()
  WHERE id = v_target.id;

  RETURN jsonb_build_object(
    'username', v_target.username,
    'is_banned', true,
    'banned_until', p_banned_until,
    'reason', trim(p_reason)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_unban_user(p_username text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_target public.users%ROWTYPE;
BEGIN
  IF v_admin_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.users AS admin_user
    WHERE admin_user.id = v_admin_id
      AND admin_user.is_dev IS TRUE
  ) THEN
    RAISE EXCEPTION 'Developer access required';
  END IF;

  SELECT app_user.*
  INTO v_target
  FROM public.users AS app_user
  WHERE lower(app_user.username) = lower(trim(p_username))
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Username not found: %', p_username;
  END IF;

  UPDATE public.users
  SET is_banned = false,
      banned_until = NULL,
      ban_reason = NULL,
      updated_at = now()
  WHERE id = v_target.id;

  RETURN jsonb_build_object(
    'username', v_target.username,
    'is_banned', false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_give_resource(
  p_kind text,
  p_username text,
  p_quantity numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_target public.users%ROWTYPE;
  v_wallet public.user_wallets%ROWTYPE;
  v_kind text := lower(trim(p_kind));
  v_currency text;
  v_currency_type text;
  v_balance_before numeric(18, 4);
  v_balance_after numeric(18, 4);
  v_new_expiry timestamptz;
BEGIN
  IF v_admin_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.users AS admin_user
    WHERE admin_user.id = v_admin_id
      AND admin_user.is_dev IS TRUE
  ) THEN
    RAISE EXCEPTION 'Developer access required';
  END IF;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Quantity must be greater than zero';
  END IF;

  SELECT app_user.*
  INTO v_target
  FROM public.users AS app_user
  WHERE lower(app_user.username) = lower(trim(p_username))
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Username not found: %', p_username;
  END IF;

  IF v_kind IN ('pro', 'ultra') THEN
    IF p_quantity <> trunc(p_quantity) OR p_quantity > 36500 THEN
      RAISE EXCEPTION 'Subscription quantity must be whole days (maximum 36500)';
    END IF;

    IF v_kind = lower(v_target.subscription_tier)
       AND v_target.subscription_expires_at > now() THEN
      v_new_expiry := v_target.subscription_expires_at
        + (p_quantity::integer * interval '1 day');
    ELSE
      v_new_expiry := now() + (p_quantity::integer * interval '1 day');
    END IF;

    UPDATE public.users
    SET subscription_tier = upper(v_kind),
        subscription_expires_at = v_new_expiry,
        updated_at = now()
    WHERE id = v_target.id;

    RETURN jsonb_build_object(
      'username', v_target.username,
      'kind', upper(v_kind),
      'days', p_quantity::integer,
      'expires_at', v_new_expiry
    );
  END IF;

  CASE v_kind
    WHEN 'ast' THEN v_currency := 'AST';
    WHEN 'coin' THEN v_currency := 'ISOTOPE';
    ELSE
      RAISE EXCEPTION 'Unsupported resource: %', p_kind;
  END CASE;

  IF p_quantity <> round(p_quantity, 4) THEN
    RAISE EXCEPTION 'Currency quantity supports at most four decimal places';
  END IF;

  INSERT INTO public.user_wallets (user_id)
  VALUES (v_target.id)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT *
  INTO v_wallet
  FROM public.user_wallets
  WHERE user_id = v_target.id
  FOR UPDATE;

  IF v_wallet.wallet_status <> 'ACTIVE' THEN
    RAISE EXCEPTION 'Target wallet is not active';
  END IF;

  IF v_currency = 'AST' THEN
    v_balance_before := v_wallet.ast_balance;
    v_balance_after := v_balance_before + p_quantity;
    UPDATE public.user_wallets
    SET ast_balance = v_balance_after,
        version = version + 1
    WHERE user_id = v_target.id;
  ELSE
    v_balance_before := v_wallet.isotope_coin_balance;
    v_balance_after := v_balance_before + p_quantity;
    UPDATE public.user_wallets
    SET isotope_coin_balance = v_balance_after,
        version = version + 1
    WHERE user_id = v_target.id;
  END IF;

  SELECT pg_catalog.format_type(currency_column.atttypid, currency_column.atttypmod)
  INTO v_currency_type
  FROM pg_catalog.pg_attribute AS currency_column
  WHERE currency_column.attrelid = 'public.wallet_transactions'::regclass
    AND currency_column.attname = 'currency'
    AND currency_column.attnum > 0
    AND NOT currency_column.attisdropped;

  IF v_currency_type IS NULL THEN
    RAISE EXCEPTION 'Could not determine wallet transaction currency type';
  END IF;

  EXECUTE pg_catalog.format(
    'INSERT INTO public.wallet_transactions (
       user_id, currency, amount, balance_before, balance_after, type,
       transaction_type, reference_type, reference_id, description, status
     )
     VALUES ($1, $2::%s, $3, $4, $5, $6, $7, $8, $9, $10, $11)',
    v_currency_type
  )
  USING
    v_target.id,
    v_currency,
    p_quantity,
    v_balance_before,
    v_balance_after,
    'ADMIN_ADJUST',
    'ADMIN_ADJUST',
    'ADMIN_TERMINAL',
    v_admin_id::text,
    'Manual resource grant by developer ' || v_admin_id::text,
    'SUCCESS';

  RETURN jsonb_build_object(
    'username', v_target.username,
    'kind', v_kind,
    'quantity', p_quantity,
    'balance', v_balance_after
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_maintenance_mode(
  p_enabled boolean,
  p_message text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_setting public.app_runtime_settings%ROWTYPE;
BEGIN
  IF v_admin_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.users AS admin_user
    WHERE admin_user.id = v_admin_id
      AND admin_user.is_dev IS TRUE
  ) THEN
    RAISE EXCEPTION 'Developer access required';
  END IF;

  UPDATE public.app_runtime_settings
  SET maintenance_mode = p_enabled,
      maintenance_message = CASE
        WHEN p_enabled
          THEN COALESCE(
            NULLIF(trim(p_message), ''),
            'Hệ thống đang bảo trì khẩn cấp'
          )
        ELSE maintenance_message
      END,
      updated_at = now(),
      updated_by = v_admin_id
  WHERE id = 1
  RETURNING * INTO v_setting;

  RETURN jsonb_build_object(
    'maintenance_mode', v_setting.maintenance_mode,
    'maintenance_message', v_setting.maintenance_message,
    'updated_at', v_setting.updated_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_maintenance_mode(boolean, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_maintenance_mode(boolean, text)
  TO authenticated;

REVOKE ALL ON FUNCTION public.admin_ban_user(text, timestamptz, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_unban_user(text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_give_resource(text, text, numeric)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_ban_user(text, timestamptz, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_unban_user(text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_give_resource(text, text, numeric)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
