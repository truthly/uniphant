CREATE TABLE roles (
role_id integer NOT NULL GENERATED ALWAYS AS IDENTITY,
role_name text NOT NULL,
PRIMARY KEY (role_id),
UNIQUE (role_name)
);

SELECT pg_catalog.pg_extension_config_dump('roles', '');
