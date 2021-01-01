CREATE OR REPLACE VIEW api.permissions AS
SELECT
permissions.permission_id,
roles.role_name,
resources.resource_name
FROM permissions
JOIN roles
  ON roles.role_id = permissions.role_id
JOIN resources
  ON resources.resource_id = permissions.resource_id;
