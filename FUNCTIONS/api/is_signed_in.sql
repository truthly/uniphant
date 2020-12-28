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

ALTER FUNCTION api.is_signed_in() OWNER TO api;
