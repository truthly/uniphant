CREATE OR REPLACE FUNCTION api.verify_assertion(
  credential_id text,
  credential_type webauthn.credential_type,
  authenticator_data text,
  client_data_json text,
  signature text,
  user_handle text
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT
  CASE credentials.valid
  WHEN TRUE THEN set_user_id(users.user_id)
  WHEN FALSE THEN FALSE
  END
FROM webauthn.verify_assertion(
  credential_id      := credential_id,
  credential_type    := credential_type,
  authenticator_data := authenticator_data,
  client_data_json   := client_data_json,
  signature          := signature,
  user_handle        := user_handle
) AS webauthn_verify_assertion
JOIN users
  ON users.user_random_id = webauthn_verify_assertion.user_id
JOIN credentials
  ON credentials.credential_bytea_id = webauthn.base64url_decode(verify_assertion.credential_id)
$$;
