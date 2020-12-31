DROP FUNCTION api.make_credential(credential_id text, credential_type webauthn.credential_type, attestation_object text, client_data_json text);
ALTER TABLE users RENAME COLUMN make_credential_at TO store_credential_at;
ALTER TABLE users RENAME COLUMN make_credential_ip TO store_credential_ip;
