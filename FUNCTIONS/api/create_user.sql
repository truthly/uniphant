CREATE OR REPLACE FUNCTION api.create_user(username text)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
DECLARE
_user_id bigint;
BEGIN
INSERT INTO users
  (username, parent_user_id)
VALUES
  (username, user_id())
RETURNING user_id
INTO STRICT _user_id;

PERFORM api.grant_role_to_user(
  role_id := (SELECT role_id FROM roles WHERE role_name = 'signed-in'),
  user_id := _user_id
);

RETURN _user_id;
END
$$;
