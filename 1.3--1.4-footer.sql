--
-- insert any existing credentials into the new public.credentials table,
-- since before we only had webauthn.credentials and no "valid" column,
-- therefore assume all existing credentials are valid=TRUE.
--
INSERT INTO credentials
  (credential_bytea_id, device_name, user_id, valid)
SELECT
  credentials.credential_id,
  credential_challenges.user_display_name,
  users.user_id,
  TRUE
FROM webauthn.credentials
JOIN users
  ON users.user_random_id = credentials.user_id
JOIN webauthn.credential_challenges
  ON credential_challenges.challenge = credentials.challenge
;
