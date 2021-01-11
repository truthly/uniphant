CREATE OR REPLACE FUNCTION auth()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
DECLARE
_request_path constant text := current_setting('request.path');
_resource_id integer;
_user_id bigint;
BEGIN
IF _request_path = '/' THEN
  -- Swagger OpenAPI specification
  RETURN;
END IF;

--
-- Authentication
--
SELECT access_tokens.user_id
INTO _user_id
FROM access_tokens
WHERE access_tokens.access_token = NULLIF(current_setting('request.cookie.access_token', TRUE),'')::uuid
AND (access_tokens.expire_at > now()) IS NOT FALSE;
IF NOT FOUND THEN
  _user_id := 0; -- anonymous
END IF;
PERFORM set_user_id(_user_id, _issue_access_token := FALSE);

--
-- Authorization
--
SELECT resource_id
INTO  _resource_id
FROM resources
WHERE resource_path = _request_path;
IF NOT check_resource_access(_resource_id) THEN
  RAISE insufficient_privilege;
END IF;

RETURN;

END
$$;
