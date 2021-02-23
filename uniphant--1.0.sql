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
verify_assertion_access_token_cookie_max_age interval NOT NULL DEFAULT '1 month'::interval,
PRIMARY KEY (setting_id),
CHECK (setting_id = 1)
);

SELECT pg_catalog.pg_extension_config_dump('settings', '');

INSERT INTO settings (setting_id) VALUES (1);
CREATE TABLE users (
user_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
user_random_id bytea NOT NULL DEFAULT gen_random_bytes(64),
username text NOT NULL,
display_name text NOT NULL,
sign_up_at timestamptz NOT NULL DEFAULT now(),
sign_up_ip inet NOT NULL,
make_credential_at timestamptz,
make_credential_ip inet,
PRIMARY KEY (user_id)
);

SELECT pg_catalog.pg_extension_config_dump('users', '');
CREATE TABLE tokens (
token uuid NOT NULL DEFAULT gen_random_uuid(),
user_id bigint NOT NULL REFERENCES users,
expire_at timestamptz NOT NULL,
PRIMARY KEY (token)
);

SELECT pg_catalog.pg_extension_config_dump('tokens', '');
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
  '[{"Set-Cookie": "access_token=%s; path=/; %s; SameSite=Strict; Expires=%s"}]',
  new_token.token,
  CASE WHEN effective_domain() = 'localhost' THEN 'HttpOnly' ELSE 'HttpOnly; Secure' END,
  to_char(new_token.expire_at AT TIME ZONE 'GMT','Dy, DD Mon YYYY HH:MI:SS GMT')
), TRUE) IS NOT NULL
$$;

CREATE OR REPLACE FUNCTION api.is_signed_in()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT format('%s (%s)', username, display_name)
FROM tokens
JOIN users ON users.user_id = tokens.user_id
WHERE tokens.token = NULLIF(current_setting('request.cookie.access_token', TRUE),'')::uuid
AND tokens.expire_at > now();
$$;

CREATE OR REPLACE FUNCTION api.sign_out()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
WITH delete_token AS (
  DELETE FROM tokens
  WHERE token = NULLIF(current_setting('request.cookie.access_token', TRUE),'')::uuid
  RETURNING TRUE
)
SELECT set_config('response.headers', format('[{"Set-Cookie": "access_token=deleted; path=/; HttpOnly; SameSite=Strict; Expires=Thu, 01 Jan 1970 00:00:01 GMT"}]'), TRUE) IS NOT NULL
$$;
