CREATE OR REPLACE FUNCTION auto_add_new_resources()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
_resource_type text;
_resource_name text;
_role_id integer;
_resource_id integer;
BEGIN

SELECT role_id
INTO STRICT _role_id
FROM roles
WHERE role_name = '*';

FOR _resource_type, _resource_name IN
  SELECT 'function', pg_proc.proname
  FROM pg_proc
  JOIN pg_namespace ON pg_namespace.oid = pg_proc.pronamespace
  WHERE pg_namespace.nspname = 'api'
  AND NOT EXISTS (
    SELECT 1 FROM resources
    WHERE resources.resource_name = pg_proc.proname
  )
  UNION ALL
  SELECT 'view', pg_class.relname
  FROM pg_class
  JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
  WHERE pg_namespace.nspname = 'api'
  AND pg_class.relkind = 'v'
  AND NOT EXISTS (
    SELECT 1 FROM resources
    WHERE resources.resource_name = pg_class.relname
  )
LOOP
  _resource_id := register_resource(
    resource_type := _resource_type,
    resource_name := _resource_name
  );
  PERFORM api.grant_resource_to_role(
    resource_id := _resource_id,
    role_id := _role_id
  );
END LOOP;

RETURN;
END
$$;
