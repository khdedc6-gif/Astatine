CREATE OR REPLACE FUNCTION public.get_user_subscription_tier(
  p_user_id uuid
)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_tier text;
  v_expires_at timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT subscription_tier, subscription_expires_at
  INTO v_tier, v_expires_at
  FROM public.users
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN 'FREE';
  END IF;

  IF v_tier NOT IN ('PRO', 'ULTRA')
     OR v_expires_at IS NULL
     OR v_expires_at <= now() THEN
    RETURN 'FREE';
  END IF;

  RETURN v_tier;
END;
$$;

REVOKE ALL ON FUNCTION public.get_user_subscription_tier(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_user_subscription_tier(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_user_subscription_tier(uuid)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
