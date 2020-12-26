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

ALTER FUNCTION api.sign_out() OWNER TO api;
