DROP FUNCTION api.get_credentials();
DROP FUNCTION api.init_credential(device_name text);
DROP FUNCTION api.is_signed_in();
DROP FUNCTION api.sign_up(username text);
ALTER TABLE users DROP COLUMN store_credential_at;
ALTER TABLE users DROP COLUMN store_credential_ip;
ALTER TABLE users DROP COLUMN sign_up_at;
ALTER TABLE users DROP COLUMN sign_up_ip;
ALTER TABLE users ADD COLUMN parent_user_id bigint REFERENCES users;
ALTER TABLE settings ADD COLUMN new_credential_valid_without_confirmation boolean NOT NULL DEFAULT TRUE;
ALTER TABLE settings RENAME COLUMN get_credentials_user_verification TO sign_in_user_verification;
ALTER TABLE settings RENAME COLUMN get_credentials_timeout TO sign_in_timeout;