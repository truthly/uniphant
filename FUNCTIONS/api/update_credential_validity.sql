CREATE OR REPLACE FUNCTION api.update_credential_validity(
  credential_id bigint,
  valid boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
DECLARE
_ok boolean;
BEGIN

IF EXISTS (
  SELECT 1
  FROM credentials
  WHERE credentials.credential_id = update_credential_validity.credential_id
  AND credentials.user_id = user_id()
)
OR has_role('admin')
THEN
  UPDATE credentials
  SET valid = update_credential_validity.valid
  WHERE credentials.credential_id = update_credential_validity.credential_id
  RETURNING TRUE
  INTO STRICT _ok;
END IF;

RETURN _ok;

END
$$;
