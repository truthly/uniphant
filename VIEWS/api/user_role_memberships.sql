CREATE OR REPLACE VIEW api.user_role_memberships AS
SELECT
roles.role_name
FROM role_memberships
JOIN roles
  ON roles.role_id = role_memberships.role_id
WHERE role_memberships.user_id = user_id();
