CREATE TABLE permissions (
permission_id integer NOT NULL GENERATED ALWAYS AS IDENTITY,
role_id integer NOT NULL REFERENCES roles,
resource_id integer NOT NULL REFERENCES resources,
PRIMARY KEY (permission_id),
UNIQUE (role_id, resource_id)
);

SELECT pg_catalog.pg_extension_config_dump('permissions', '');
