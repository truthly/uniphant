CREATE OR REPLACE FUNCTION api.verify_assertion(credential_id text, credential_type webauthn.credential_type, authenticator_data text, client_data_json text, signature text, user_handle text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT issue_access_token(users.user_id)
FROM webauthn.verify_assertion(
  credential_id := credential_id,
  credential_type := credential_type,
  authenticator_data := authenticator_data,
  client_data_json := client_data_json,
  signature := signature,
  user_handle := user_handle
)
JOIN users ON users.user_random_id = verify_assertion.user_id
$$;

ALTER FUNCTION api.verify_assertion(credential_id text, credential_type webauthn.credential_type, authenticator_data text, client_data_json text, signature text, user_handle text) OWNER TO api;
