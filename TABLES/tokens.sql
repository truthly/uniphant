CREATE TABLE tokens (
token uuid NOT NULL DEFAULT gen_random_uuid(),
user_id bigint NOT NULL REFERENCES users,
expire_at timestamptz,
PRIMARY KEY (token)
);

SELECT pg_catalog.pg_extension_config_dump('tokens', '');
