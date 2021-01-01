CREATE OR REPLACE FUNCTION api.openapi_swagger()
RETURNS jsonb
STABLE
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT jsonb_set(openapi_swagger_doc,'{paths}',jsonb_object_agg(path, openapi_swagger_doc->'paths'->path))
FROM openapi_swagger
CROSS JOIN jsonb_object_keys(openapi_swagger_doc->'paths') AS path
JOIN resources ON resources.resource_path = path
              AND check_resource_access(resources.resource_id)
GROUP BY openapi_swagger_doc
$$;
