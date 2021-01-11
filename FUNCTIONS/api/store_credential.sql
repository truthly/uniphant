CREATE OR REPLACE FUNCTION api.store_credential(
  credential_id text,
  credential_type webauthn.credential_type,
  attestation_object text,
  client_data_json text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
DECLARE
_user_random_id bytea;
_user_id bigint;
_valid boolean;
_ok boolean;
BEGIN
_user_random_id := webauthn.store_credential(
  credential_id      := credential_id,
  credential_type    := credential_type,
  attestation_object := attestation_object,
  client_data_json   := client_data_json
);

SELECT
  users.user_id
INTO STRICT
  _user_id
FROM users
WHERE users.user_random_id = _user_random_id;

IF user_id() = _user_id THEN
  _valid := TRUE;
ELSIF (SELECT new_credential_valid_without_confirmation FROM settings) THEN
  PERFORM set_user_id(_user_id);
  _valid := TRUE;
ELSE
  _valid := FALSE;
END IF;

INSERT INTO credentials
  (credential_bytea_id, device_name, user_id, valid)
SELECT
  credentials.credential_id,
  credential_challenges.user_display_name,
  users.user_id,
  _valid
FROM webauthn.credentials
JOIN users
  ON users.user_random_id = credentials.user_id
JOIN webauthn.credential_challenges
  ON credential_challenges.challenge = credentials.challenge
WHERE credentials.credential_id = webauthn.base64url_decode(store_credential.credential_id)
AND credentials.user_id = _user_random_id
RETURNING TRUE
INTO STRICT _ok;

-- inform the user if the credential has to be marked as valid
-- before it can be used to sign-in
RETURN _valid;
END
$$;
