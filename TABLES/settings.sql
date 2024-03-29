CREATE TABLE settings (
setting_id integer NOT NULL,
init_credential_relying_party_name text NOT NULL DEFAULT 'ACME Corporation',
init_credential_require_resident_key boolean DEFAULT TRUE,
init_credential_user_verification webauthn.user_verification_requirement NOT NULL DEFAULT 'discouraged',
init_credential_attestation webauthn.attestation_conveyance_preference NOT NULL DEFAULT 'none',
init_credential_timeout interval NOT NULL DEFAULT '5 minutes'::interval,
sign_in_user_verification webauthn.user_verification_requirement NOT NULL DEFAULT 'discouraged',
sign_in_timeout interval NOT NULL DEFAULT '5 minutes'::interval,
verify_assertion_access_token_cookie_max_age interval DEFAULT NULL::interval, -- NULL=session cookie (default)
new_credential_valid_without_confirmation boolean NOT NULL DEFAULT TRUE,
PRIMARY KEY (setting_id),
CHECK (setting_id = 1)
);

SELECT pg_catalog.pg_extension_config_dump('settings', '');

INSERT INTO settings (setting_id) VALUES (1);
