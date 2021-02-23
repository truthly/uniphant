-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION uniphant" to load this file. \quit
CREATE SCHEMA IF NOT EXISTS AUTHORIZATION api;
GRANT USAGE ON SCHEMA api TO web_anon;
GRANT USAGE ON SCHEMA webauthn TO web_anon;
GRANT web_anon TO postgrest;
CREATE OR REPLACE FUNCTION effective_domain()
RETURNS text
STABLE
LANGUAGE sql
AS $$
/*
  This function is compatible with PostgREST.

  See: https://postgrest.org/en/v7.0.0/api.html#accessing-request-headers-cookies-and-jwt-claims

  We could have used a regex to extract the host from the URL,
  but since ts_debug() has this capability, let's use it.
  The only annoyance is the special case when there is no TLD,
  such as for "http://localhost", in which case the returned alias
  is "asciiweord", which is why we need the "WHERE COUNT = 1"
  wrapper, to ensure not more than one row matched,
  which would be ambiguous.
*/
SELECT token FROM (
  SELECT token, COUNT(*) OVER ()
  FROM ts_debug(current_setting('request.header.origin', TRUE))
  WHERE alias IN ('host','asciiword')
) AS X WHERE COUNT = 1
$$;
CREATE OR REPLACE FUNCTION remote_ip()
RETURNS inet
STABLE
LANGUAGE sql
AS $$
/*
  This function is compatible with PostgREST.

  See: https://postgrest.org/en/v7.0.0/api.html#accessing-request-headers-cookies-and-jwt-claims

  If using nginx, you also need to add this line to your nginx.conf:
    proxy_set_header X-Forwarded-For $remote_addr;

  See nginx.conf in this repo for a complete example.
*/
SELECT current_setting('request.header.X-Forwarded-For', TRUE)::inet
$$;
CREATE TABLE settings (
setting_id integer NOT NULL,
init_credential_relying_party_name text NOT NULL DEFAULT 'ACME Corporation',
init_credential_require_resident_key boolean DEFAULT TRUE,
init_credential_user_verification webauthn.user_verification_requirement NOT NULL DEFAULT 'discouraged',
init_credential_attestation webauthn.attestation_conveyance_preference NOT NULL DEFAULT 'none',
init_credential_timeout interval NOT NULL DEFAULT '5 minutes'::interval,
get_credentials_user_verification webauthn.user_verification_requirement NOT NULL DEFAULT 'discouraged',
get_credentials_timeout interval NOT NULL DEFAULT '5 minutes'::interval,
verify_assertion_access_token_cookie_max_age interval DEFAULT NULL::interval, -- NULL=session cookie (default)
PRIMARY KEY (setting_id),
CHECK (setting_id = 1)
);

SELECT pg_catalog.pg_extension_config_dump('settings', '');

INSERT INTO settings (setting_id) VALUES (1);
CREATE TABLE users (
user_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
user_random_id bytea NOT NULL DEFAULT gen_random_bytes(64),
username text NOT NULL,
sign_up_at timestamptz NOT NULL DEFAULT now(),
sign_up_ip inet NOT NULL,
store_credential_at timestamptz,
store_credential_ip inet,
PRIMARY KEY (user_id)
);

SELECT pg_catalog.pg_extension_config_dump('users', '');
CREATE TABLE access_tokens (
access_token uuid NOT NULL DEFAULT gen_random_uuid(),
user_id bigint NOT NULL REFERENCES users,
expire_at timestamptz,
PRIMARY KEY (access_token)
);

SELECT pg_catalog.pg_extension_config_dump('access_tokens', '');
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

CREATE OR REPLACE FUNCTION api.get_credential_creation_options(challenge text)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT webauthn.get_credential_creation_options(webauthn.base64url_decode(challenge))
$$;
