CREATE OR REPLACE FUNCTION api.create_role(role_name text)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
INSERT INTO roles
  (role_name)
VALUES
  (role_name)
RETURNING role_id
$$;
