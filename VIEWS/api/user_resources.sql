CREATE OR REPLACE VIEW api.user_resources WITH (security_barrier) AS
SELECT
resource_id,
resource_type,
resource_name,
resource_path
FROM resources
WHERE check_resource_access(resource_id);
