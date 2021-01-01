CREATE OR REPLACE FUNCTION api.grant_role_to_user(
  role_id integer,
  user_id bigint
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
INSERT INTO role_memberships
  (user_id, role_id)
VALUES
  (user_id, role_id)
RETURNING TRUE
$$;
