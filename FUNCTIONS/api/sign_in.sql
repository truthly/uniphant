CREATE OR REPLACE FUNCTION api.sign_in()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT webauthn.get_credentials(
  challenge         := gen_random_bytes(32),
  user_verification := settings.sign_in_user_verification,
  timeout           := settings.sign_in_timeout
)
FROM settings
$$;
