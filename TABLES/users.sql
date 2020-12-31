CREATE TABLE users (
user_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
user_random_id bytea NOT NULL DEFAULT gen_random_bytes(64),
username text NOT NULL,
sign_up_at timestamptz NOT NULL DEFAULT now(),
sign_up_ip inet NOT NULL,
store_credential_at timestamptz,
store_credential_ip inet,
PRIMARY KEY (user_id)
);

SELECT pg_catalog.pg_extension_config_dump('users', '');
