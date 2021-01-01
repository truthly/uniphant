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
BEGIN
_user_random_id := webauthn.store_credential(
  credential_id      := credential_id,
  credential_type    := credential_type,
  attestation_object := attestation_object,
  client_data_json   := client_data_json
);

INSERT INTO credentials
  (credential_bytea_id, device_name, user_id, valid)
SELECT
  credentials.credential_id,
  credential_challenges.user_display_name,
  users.user_id,
  CASE
    WHEN user_id() = users.user_id -- user signed-in already and is the same as the credential's user_id
    THEN TRUE
    ELSE settings.new_credential_valid_without_confirmation
  END
FROM webauthn.credentials
JOIN users
  ON users.user_random_id = credentials.user_id
JOIN webauthn.credential_challenges
  ON credential_challenges.challenge = credentials.challenge
CROSS JOIN settings
WHERE credentials.credential_id = webauthn.base64url_decode(store_credential.credential_id)
AND credentials.user_id = _user_random_id
RETURNING user_id, valid
INTO STRICT _user_id, _valid;

IF user_id() IS NOT NULL THEN
  -- user is already signed-in
  RETURN TRUE;
ELSIF _valid THEN
  -- user not signed-in,
  -- and newly created credential is immediately valid,
  -- so issue access token causing the user to be signed-in
  PERFORM issue_access_token(_user_id);
  RETURN TRUE;
END IF;

-- tell the user the credential has to be marked as valid
-- before it can be used to sign-in
RETURN FALSE;
END
$$;
