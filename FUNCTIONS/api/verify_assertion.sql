CREATE OR REPLACE FUNCTION api.verify_assertion(OUT token uuid, credential_id text, credential_type webauthn.credential_type, authenticator_data text, client_data_json text, signature text, user_handle text)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
WITH
verify AS (
  SELECT user_id
  FROM webauthn.verify_assertion(
    credential_id := credential_id,
    credential_type := credential_type,
    authenticator_data := authenticator_data,
    client_data_json := client_data_json,
    signature := signature,
    user_handle := user_handle
  )
),
new_token AS (
  INSERT INTO tokens (user_id)
  SELECT users.user_id
  FROM verify
  JOIN users ON users.user_random_id = verify.user_id
  RETURNING tokens.token
)
SELECT token
FROM new_token
--
-- In production, make sure to add "Secure;":
-- WHERE set_config('response.headers', format('[{"Set-Cookie": "access_token=%s; path=/; Secure; HttpOnly; SameSite=Strict; max-age=86400"}]', token), TRUE) IS NOT NULL
--
WHERE set_config('response.headers', format(
  '[{"Set-Cookie": "access_token=%s; path=/; %s; SameSite=Strict; max-age=86400"}]',
  token,
  CASE WHEN effective_domain() = 'localhost' THEN 'HttpOnly' ELSE 'HttpOnly; Secure' END
), TRUE) IS NOT NULL
$$;

ALTER FUNCTION api.verify_assertion(credential_id text, credential_type webauthn.credential_type, authenticator_data text, client_data_json text, signature text, user_handle text) OWNER TO api;
