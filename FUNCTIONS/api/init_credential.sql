CREATE OR REPLACE FUNCTION api.init_credential(device_name text, other_device boolean)
RETURNS TABLE (
  credential_creation_options jsonb,
  other_device boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT
  webauthn.init_credential(
    challenge            := gen_random_bytes(32),
    relying_party_name   := settings.init_credential_relying_party_name,
    user_name            := users.username,
    user_id              := users.user_random_id,
    user_display_name    := init_credential.device_name,
    require_resident_key := settings.init_credential_require_resident_key,
    user_verification    := settings.init_credential_user_verification,
    attestation          := settings.init_credential_attestation,
    timeout              := settings.init_credential_timeout
  ),
  init_credential.other_device
FROM users
CROSS JOIN settings
WHERE users.user_id = user_id()
$$;
