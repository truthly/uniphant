--
-- grant select access on all views in the api schema by default,
-- which also requires select access on the underlying tables
-- in the public schema.
--
-- ("ON ALL TABLES" is not a typo; VIEWS are included in TABLES,
-- there is no specific VIEWS command.)
--

GRANT SELECT ON ALL TABLES IN SCHEMA api TO web_anon;

GRANT SELECT ON
  credentials,
  openapi_swagger,
  permissions,
  resources,
  role_memberships,
  roles,
  settings,
  users
TO web_anon;

--
-- allow web_anon to call functions in the api schema
--
GRANT USAGE ON SCHEMA api TO web_anon;
