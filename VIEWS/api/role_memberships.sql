CREATE OR REPLACE VIEW api.role_memberships AS
SELECT
role_memberships.role_membership_id,
role_memberships.user_id,
roles.role_name
FROM role_memberships
JOIN roles
  ON roles.role_id = role_memberships.role_id;
