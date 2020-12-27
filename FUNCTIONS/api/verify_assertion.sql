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
  INSERT INTO tokens (user_id, expire_at)
  SELECT users.user_id, now() + settings.verify_assertion_access_token_cookie_max_age
  FROM verify
  CROSS JOIN settings
  JOIN users ON users.user_random_id = verify.user_id
  RETURNING tokens.token, tokens.expire_at
)
SELECT new_token.token
FROM new_token
CROSS JOIN settings
WHERE set_config('response.headers', format(
  '[{"Set-Cookie": "access_token=%s; path=/; HttpOnly; SameSite=Strict%s%s"}]',
  new_token.token,
  CASE WHEN effective_domain() = 'localhost' THEN '' ELSE '; Secure' END,
  '; Expires=' || to_char(new_token.expire_at AT TIME ZONE 'GMT','Dy, DD Mon YYYY HH:MI:SS GMT')
), TRUE) IS NOT NULL
$$;

ALTER FUNCTION api.verify_assertion(credential_id text, credential_type webauthn.credential_type, authenticator_data text, client_data_json text, signature text, user_handle text) OWNER TO api;
