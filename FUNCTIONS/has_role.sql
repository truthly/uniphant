CREATE OR REPLACE FUNCTION has_role(role_name text)
RETURNS boolean
STABLE
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT EXISTS (
  SELECT 1
  FROM role_memberships
  JOIN roles
    ON roles.role_id = role_memberships.role_id
  WHERE role_memberships.user_id = user_id()
  AND roles.role_name = has_role.role_name
)
$$;
