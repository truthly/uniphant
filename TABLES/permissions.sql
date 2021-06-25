CREATE TABLE permissions (
permission_id integer NOT NULL GENERATED ALWAYS AS IDENTITY,
role_id integer NOT NULL,
resource_id integer NOT NULL,
PRIMARY KEY (permission_id),
FOREIGN KEY (role_id) REFERENCES roles,
FOREIGN KEY (resource_id) REFERENCES resources,
UNIQUE (role_id, resource_id)
);

SELECT pg_catalog.pg_extension_config_dump('permissions', '');
