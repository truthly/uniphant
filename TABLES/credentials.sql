CREATE TABLE credentials (
credential_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
credential_bytea_id bytea NOT NULL REFERENCES webauthn.credentials,
device_name text NOT NULL,
user_id bigint NOT NULL REFERENCES users,
valid boolean NOT NULL,
PRIMARY KEY (credential_id),
UNIQUE (credential_bytea_id)
);

SELECT pg_catalog.pg_extension_config_dump('credentials', '');
