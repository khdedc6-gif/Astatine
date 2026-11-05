ALTER TABLE public.app_branding_assets
  ADD COLUMN IF NOT EXISTS login_background_scale double precision
    NOT NULL DEFAULT 1 CHECK (login_background_scale BETWEEN 1 AND 3),
  ADD COLUMN IF NOT EXISTS login_background_x double precision
    NOT NULL DEFAULT 0 CHECK (login_background_x BETWEEN -1 AND 1),
  ADD COLUMN IF NOT EXISTS login_background_y double precision
    NOT NULL DEFAULT 0 CHECK (login_background_y BETWEEN -1 AND 1),
  ADD COLUMN IF NOT EXISTS overview_illustration_scale double precision
    NOT NULL DEFAULT 1 CHECK (overview_illustration_scale BETWEEN 1 AND 3),
  ADD COLUMN IF NOT EXISTS overview_illustration_x double precision
    NOT NULL DEFAULT 0 CHECK (overview_illustration_x BETWEEN -1 AND 1),
  ADD COLUMN IF NOT EXISTS overview_illustration_y double precision
    NOT NULL DEFAULT 0 CHECK (overview_illustration_y BETWEEN -1 AND 1);
