CREATE OR REPLACE FUNCTION user_id()
RETURNS bigint
STABLE
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT NULLIF(current_setting('uniphant.user_id',TRUE),'')::bigint
$$;
