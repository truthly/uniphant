CREATE OR REPLACE FUNCTION api.sign_up(username text, device_name text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
DECLARE
_user_id bigint;
BEGIN

_user_id := api.create_user(username);

--
-- The first user who signs-up
-- automatically gets the admin role.
--
-- This is to simplify installations,
-- as otherwise the admin would need
-- database access to grant its user access.
--
-- (user_id 0 is the anonymous user.)
--
IF _user_id = 1 THEN
  PERFORM api.grant_role_to_user(
    role_id := (SELECT role_id FROM roles WHERE role_name = 'admin'),
    user_id := _user_id
  );
END IF;

--
-- Set user_id allowing sign_up() to be used
-- in conjunction with init_credential()
-- that calls user_id().
--
PERFORM set_user_id(_user_id);

PERFORM issue_access_token(_user_id);

RETURN (SELECT credential_creation_options FROM api.init_credential(device_name, FALSE));

END
$$;
