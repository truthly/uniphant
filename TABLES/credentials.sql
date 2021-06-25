CREATE TABLE credentials (
credential_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
credential_bytea_id bytea NOT NULL,
device_name text NOT NULL,
user_id bigint NOT NULL,
valid boolean NOT NULL,
PRIMARY KEY (credential_id),
FOREIGN KEY (credential_bytea_id) REFERENCES webauthn.credentials,
FOREIGN KEY (user_id) REFERENCES users,
UNIQUE (credential_bytea_id)
);

SELECT pg_catalog.pg_extension_config_dump('credentials', '');
