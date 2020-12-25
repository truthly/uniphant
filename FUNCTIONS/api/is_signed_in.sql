CREATE OR REPLACE FUNCTION api.is_signed_in()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT format('%s (%s)', username, display_name)
FROM tokens
JOIN users ON users.user_id = tokens.user_id
WHERE tokens.token = NULLIF(current_setting('request.cookie.access_token', TRUE),'')::uuid;
$$;

ALTER FUNCTION api.is_signed_in() OWNER TO api;
