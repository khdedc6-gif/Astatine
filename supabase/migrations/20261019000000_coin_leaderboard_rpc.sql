-- ---------------------------------------------------------------------------
-- Leaderboard RPC: returns top users ranked by Isotope Coin balance.
-- Uses SECURITY DEFINER so the function can read all wallets even though
-- the row-level-security policy on user_wallets restricts each user to
-- their own row only.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_coin_leaderboard(p_limit int DEFAULT 50)
RETURNS TABLE (
  user_id   uuid,
  full_name text,
  coin      numeric
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT
    uw.user_id,
    COALESCE(p.full_name, u.username, uw.user_id::text) AS full_name,
    uw.isotope_coin_balance                               AS coin
  FROM public.user_wallets AS uw
  LEFT JOIN public.profiles AS p  ON p.id  = uw.user_id
  LEFT JOIN public.users    AS u  ON u.id  = uw.user_id
  WHERE uw.isotope_coin_balance > 0
  ORDER BY uw.isotope_coin_balance DESC
  LIMIT p_limit;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_coin_leaderboard(int) TO authenticated;

NOTIFY pgrst, 'reload schema';
