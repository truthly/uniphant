CREATE OR REPLACE VIEW api.resources AS
SELECT
resource_id,
resource_type,
resource_name,
resource_path
FROM resources;
