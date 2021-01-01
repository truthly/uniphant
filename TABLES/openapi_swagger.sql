CREATE TABLE openapi_swagger (
openapi_swagger_id integer NOT NULL,
openapi_swagger_doc jsonb NOT NULL,
PRIMARY KEY (openapi_swagger_id),
CHECK (openapi_swagger_id = 1)
);

SELECT pg_catalog.pg_extension_config_dump('openapi_swagger', '');
