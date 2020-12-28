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

ALTER FUNCTION api.sign_up(username text) OWNER TO api;
