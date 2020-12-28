CREATE TABLE access_tokens (
access_token uuid NOT NULL DEFAULT gen_random_uuid(),
user_id bigint NOT NULL REFERENCES users,
expire_at timestamptz,
PRIMARY KEY (access_token)
);

SELECT pg_catalog.pg_extension_config_dump('access_tokens', '');
