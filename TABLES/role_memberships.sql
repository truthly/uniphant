CREATE TABLE role_memberships (
role_membership_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
user_id bigint NOT NULL REFERENCES users,
role_id integer NOT NULL REFERENCES roles,
PRIMARY KEY (role_membership_id),
UNIQUE (user_id, role_id)
);

SELECT pg_catalog.pg_extension_config_dump('role_memberships', '');
