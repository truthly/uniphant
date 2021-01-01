CREATE OR REPLACE FUNCTION set_openapi_swagger(jsonb)
RETURNS boolean
LANGUAGE sql
AS $$
INSERT INTO openapi_swagger
  (openapi_swagger_id, openapi_swagger_doc)
VALUES
  (1, $1)
ON CONFLICT ON CONSTRAINT openapi_swagger_pkey DO UPDATE SET
  openapi_swagger_doc = $1
WHERE openapi_swagger.openapi_swagger_id = 1
RETURNING TRUE
$$;
