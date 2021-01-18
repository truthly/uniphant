CREATE TABLE resources (
resource_id integer NOT NULL GENERATED ALWAYS AS IDENTITY,
resource_type text NOT NULL,
resource_name text NOT NULL,
resource_path text NOT NULL GENERATED ALWAYS AS (CASE resource_type WHEN 'function' THEN '/rpc/'||resource_name WHEN 'view' THEN '/'||resource_name END) STORED,
PRIMARY KEY (resource_id),
UNIQUE (resource_name)
);

SELECT pg_catalog.pg_extension_config_dump('resources', '');
