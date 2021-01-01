CREATE OR REPLACE FUNCTION set_user_id(user_id bigint)
RETURNS void
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
RETURN;
END
$$;
