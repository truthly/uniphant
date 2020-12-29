CREATE OR REPLACE FUNCTION api.get_credential_creation_options(challenge text)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT webauthn.get_credential_creation_options(webauthn.base64url_decode(challenge))
$$;

ALTER FUNCTION api.get_credential_creation_options(challenge text) OWNER TO api;
