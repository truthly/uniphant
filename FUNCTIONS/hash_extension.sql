CREATE OR REPLACE FUNCTION hash_extension(text)
RETURNS integer
STABLE
LANGUAGE sql
AS $$
--
-- Constructs a text string containing most of all the extension objects
-- and their create definitions.
--
-- This is useful to detect a diff between the result of
-- 
--    ALTER EXTENSION ... UPDATE;
--    SELECT hash_extension(...);
--
-- compared to if one would install the latest version
-- of the extension from scratch using
--
--    CREATE EXTENSION ...;
--    SELECT hash_extension(...);
--
-- This could happen if the author of the extension
-- made a mistake in the update scripts.
--
-- This function is meant to be useful to check
-- the correctness of such update scripts.
--
SELECT hashtext(jsonb_agg(jsonb_build_array(
  pg_describe_object,
  CASE classid
  WHEN 'pg_namespace'::regclass THEN (
    SELECT jsonb_build_array(pg_roles.rolname, pg_namespace.nspacl)
    FROM pg_namespace
    JOIN pg_roles ON pg_roles.oid = pg_namespace.nspowner
    WHERE pg_namespace.oid = q.objid
  )
  WHEN 'pg_proc'::regclass THEN jsonb_build_array(pg_get_functiondef(objid))
  WHEN 'pg_class'::regclass THEN (
    SELECT jsonb_agg(jsonb_build_array(
      a.attname,
      pg_catalog.format_type(a.atttypid, a.atttypmod),
      (SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid, true) for 128)
        FROM pg_catalog.pg_attrdef d
        WHERE d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef),
      a.attnotnull,
      (SELECT c.collname FROM pg_catalog.pg_collation c, pg_catalog.pg_type t
        WHERE c.oid = a.attcollation AND t.oid = a.atttypid
        AND a.attcollation <> t.typcollation),
      a.attidentity,
      a.attgenerated
    ) ORDER BY a.attnum)
    FROM pg_catalog.pg_attribute a
    WHERE a.attrelid = q.objid
    AND a.attnum > 0
    AND NOT a.attisdropped
  )
  END,
  classid::regclass
) ORDER BY pg_describe_object)::text)
FROM (
  SELECT pg_describe_object(classid, objid, 0), classid::regclass, objid
  FROM pg_depend
  WHERE refclassid = 'pg_extension'::regclass
  AND refobjid = (SELECT oid FROM pg_extension WHERE extname = $1)
) AS q
$$;
