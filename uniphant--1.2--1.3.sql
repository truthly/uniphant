-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION uniphant" to load this file. \quit
CREATE OR REPLACE FUNCTION api.store_credential(credential_id text, credential_type webauthn.credential_type, attestation_object text, client_data_json text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
WITH make AS (
  SELECT user_id
  FROM webauthn.store_credential(
    credential_id := credential_id,
    credential_type := credential_type,
    attestation_object := attestation_object,
    client_data_json := client_data_json
  )
)
UPDATE users SET
  store_credential_at = now(),
  store_credential_ip = remote_ip()
FROM make
WHERE users.user_random_id = make.user_id
RETURNING TRUE
$$;

DROP FUNCTION api.make_credential(credential_id text, credential_type webauthn.credential_type, attestation_object text, client_data_json text);
ALTER TABLE users RENAME COLUMN make_credential_at TO store_credential_at;
ALTER TABLE users RENAME COLUMN make_credential_ip TO store_credential_ip;
