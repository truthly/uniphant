CREATE OR REPLACE FUNCTION api.get_credentials()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT webauthn.get_credentials(
  challenge := gen_random_bytes(32),
  user_verification := settings.get_credentials_user_verification,
  timeout := settings.get_credentials_timeout
)
FROM settings
$$;

ALTER FUNCTION api.get_credentials() OWNER TO api;
