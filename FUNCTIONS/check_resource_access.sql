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
  JOIN permissions ON permissions.role_id = role_memberships.role_id
  WHERE role_memberships.user_id = user_id()
  AND permissions.resource_id = _resource_id
)
$$;
