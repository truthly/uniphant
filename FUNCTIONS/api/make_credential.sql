CREATE OR REPLACE FUNCTION api.make_credential(credential_id text, credential_type webauthn.credential_type, attestation_object text, client_data_json text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
WITH make AS (
  SELECT user_id
  FROM webauthn.make_credential(
    credential_id := credential_id,
    credential_type := credential_type,
    attestation_object := attestation_object,
    client_data_json := client_data_json
  )
)
UPDATE users SET
  make_credential_at = now(),
  make_credential_ip = remote_ip()
FROM make
WHERE users.user_random_id = make.user_id
RETURNING TRUE
$$;

ALTER FUNCTION api.make_credential(credential_id text, credential_type webauthn.credential_type, attestation_object text, client_data_json text) OWNER TO api;
