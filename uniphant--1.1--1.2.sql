-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION uniphant" to load this file. \quit
CREATE OR REPLACE FUNCTION api.get_credential_creation_options(challenge text)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT webauthn.get_credential_creation_options(webauthn.base64url_decode(challenge))
$$;

ALTER TABLE settings ALTER COLUMN verify_assertion_access_token_cookie_max_age SET DEFAULT NULL::interval;
