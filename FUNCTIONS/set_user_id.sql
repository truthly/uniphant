CREATE OR REPLACE FUNCTION set_user_id(user_id bigint, _issue_access_token boolean DEFAULT TRUE)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
BEGIN
IF set_config('uniphant.user_id',user_id::text,TRUE) = user_id::text THEN
  -- Assert OK
ELSE
  RAISE EXCEPTION 'Bug! set_config() did not return the value';
END IF;
IF _issue_access_token THEN
  PERFORM issue_access_token();
END IF;
RETURN TRUE;
END
$$;
