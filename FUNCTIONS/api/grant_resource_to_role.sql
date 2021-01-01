CREATE OR REPLACE FUNCTION api.grant_resource_to_role(
  resource_id integer,
  role_id integer
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
INSERT INTO permissions
  (role_id, resource_id)
VALUES
  (role_id, resource_id)
RETURNING TRUE
$$;
