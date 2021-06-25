CREATE TABLE role_memberships (
role_membership_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
user_id bigint NOT NULL,
role_id integer NOT NULL,
PRIMARY KEY (role_membership_id),
FOREIGN KEY (user_id) REFERENCES users,
FOREIGN KEY (role_id) REFERENCES roles,
UNIQUE (user_id, role_id)
);

SELECT pg_catalog.pg_extension_config_dump('role_memberships', '');
