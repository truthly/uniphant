-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION uniphant" to load this file. \quit
ALTER TABLE settings ALTER COLUMN verify_assertion_access_token_cookie_max_age DROP NOT NULL;
ALTER TABLE tokens RENAME TO access_tokens;
ALTER TABLE access_tokens RENAME token TO access_token;
ALTER TABLE access_tokens ALTER COLUMN expire_at DROP NOT NULL;
ALTER INDEX "tokens_pkey" RENAME TO "access_tokens_pkey";
ALTER TABLE access_tokens RENAME CONSTRAINT "tokens_user_id_fkey" TO "access_tokens_user_id_fkey";
DROP FUNCTION api.verify_assertion(text,credential_type,text,text,text,text);
DROP FUNCTION api.init_credential(text,text);
ALTER TABLE users DROP COLUMN display_name;
CREATE OR REPLACE FUNCTION issue_access_token(user_id bigint)
RETURNS boolean
LANGUAGE sql
AS $$
WITH
new AS (
  INSERT INTO access_tokens (user_id, expire_at)
  SELECT issue_access_token.user_id, now() + settings.verify_assertion_access_token_cookie_max_age
  FROM settings
  RETURNING access_tokens.access_token, access_tokens.expire_at
)
SELECT set_config('response.headers', format(
  '[{"Set-Cookie": "access_token=%s; path=/; HttpOnly; SameSite=Strict%s%s"}]',
  new.access_token,
  CASE WHEN effective_domain() = 'localhost' THEN '' ELSE '; Secure' END,
  '; Expires=' || to_char(new.expire_at AT TIME ZONE 'GMT','Dy, DD Mon YYYY HH:MI:SS GMT')
), TRUE) IS NOT NULL
FROM new
$$;
CREATE OR REPLACE FUNCTION api.init_credential(device_name text)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT webauthn.init_credential(
  challenge := gen_random_bytes(32),
  relying_party_name := settings.init_credential_relying_party_name,
  user_name := users.username,
  user_id := users.user_random_id,
  user_display_name := init_credential.device_name,
  require_resident_key := settings.init_credential_require_resident_key,
  user_verification := settings.init_credential_user_verification,
  attestation := settings.init_credential_attestation,
  timeout := settings.init_credential_timeout
)
FROM users
CROSS JOIN settings
WHERE users.user_id = user_id()
$$;

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

CREATE OR REPLACE FUNCTION api.is_signed_in()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT username
FROM users
WHERE user_id = user_id()
$$;

CREATE OR REPLACE FUNCTION api.sign_out()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
WITH del AS (
  DELETE FROM access_tokens
  WHERE access_token = NULLIF(current_setting('request.cookie.access_token', TRUE),'')::uuid
  RETURNING TRUE
)
SELECT set_config('response.headers', format('[{"Set-Cookie": "access_token=deleted; path=/; HttpOnly; SameSite=Strict; Expires=Thu, 01 Jan 1970 00:00:01 GMT"}]'), TRUE) IS NOT NULL
$$;

CREATE OR REPLACE FUNCTION api.sign_up(username text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
WITH
new AS (
  INSERT INTO users (username, sign_up_ip)
  VALUES (username, remote_ip())
  RETURNING user_id
)
SELECT issue_access_token(new.user_id)
FROM new
$$;

CREATE OR REPLACE FUNCTION user_id()
RETURNS bigint
STABLE
LANGUAGE sql
AS $$
SELECT access_tokens.user_id
FROM access_tokens
WHERE access_tokens.access_token = NULLIF(current_setting('request.cookie.access_token', TRUE),'')::uuid
AND (access_tokens.expire_at > now()) IS NOT FALSE;
$$;
