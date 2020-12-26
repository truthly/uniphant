CREATE OR REPLACE FUNCTION api.init_credential(username text, display_name text)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
WITH
new_user AS (
  INSERT INTO users (username, display_name, sign_up_ip)
  VALUES (username, display_name, remote_ip())
  RETURNING user_random_id
)
SELECT webauthn.init_credential(
  challenge := gen_random_bytes(32),
  relying_party_name := settings.init_credential_relying_party_name,
  user_name := username,
  user_id := user_random_id,
  user_display_name := display_name,
  require_resident_key := settings.init_credential_require_resident_key,
  user_verification := settings.init_credential_user_verification,
  attestation := settings.init_credential_attestation,
  timeout := settings.init_credential_timeout
)
FROM new_user
CROSS JOIN settings
$$;

ALTER FUNCTION api.init_credential(username text, display_name text) OWNER TO api;
