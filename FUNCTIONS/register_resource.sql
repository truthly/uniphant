CREATE OR REPLACE FUNCTION register_resource(
resource_type text,
resource_name text
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
_resource_id integer;
BEGIN

IF resource_type = 'function' THEN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    JOIN pg_namespace ON pg_namespace.oid = pg_proc.pronamespace
    WHERE pg_proc.proname = resource_name
    AND pg_namespace.nspname = 'api'
  ) THEN
    RAISE EXCEPTION 'no function named "%" in api schema', resource_name;
  END IF;
ELSIF resource_type = 'view' THEN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
    WHERE pg_class.relname = resource_name
    AND pg_namespace.nspname = 'api'
    AND pg_class.relkind = 'v'
  ) THEN
    RAISE EXCEPTION 'no view named "%" in api schema', resource_name;
  END IF;
ELSE
  RAISE EXCEPTION 'invalid resource type "%"', resource_type;
END IF;

INSERT INTO resources
  (resource_type, resource_name)
VALUES
  (resource_type, resource_name)
RETURNING resource_id
INTO STRICT _resource_id;

RETURN _resource_id;

END
$$;
