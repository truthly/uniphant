-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION uniphant" to load this file. \quit

CREATE SCHEMA IF NOT EXISTS AUTHORIZATION api;
GRANT USAGE ON SCHEMA api TO web_anon;
GRANT USAGE ON SCHEMA webauthn TO web_anon;
GRANT web_anon TO postgrest;
CREATE OR REPLACE FUNCTION check_resource_access(_resource_id integer)
RETURNS boolean
STABLE
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT EXISTS (
  SELECT 1
  FROM role_memberships
  JOIN permissions
    ON permissions.role_id = role_memberships.role_id
  WHERE role_memberships.user_id = user_id()
  AND permissions.resource_id = _resource_id
)
$$;
