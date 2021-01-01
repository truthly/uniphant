--
-- register all functions in the api schema as resources
--
SELECT register_resource(
  resource_type := 'function',
  resource_name := pg_proc.proname
)
FROM pg_proc
JOIN pg_namespace ON pg_namespace.oid = pg_proc.pronamespace
WHERE pg_namespace.nspname = 'api';

--
-- register all views in the api schema as resources
--
SELECT register_resource(
  resource_type := 'view',
  resource_name := pg_class.relname
)
FROM pg_class
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE pg_namespace.nspname = 'api'
AND pg_class.relkind = 'v';

--
-- a special user "anonymous" is created
-- to be used when signed-out, which is
-- assigned user_id=0, to avoid collision
-- with any normal users, as the user_id
-- is guaranteed to be <=1 thanks to
-- GENERATED ALWAYS AS IDENTITY.
--
-- since usernames are not unique,
-- it is user_id=0 that determines
-- if the user is anonymous,
-- not the username.
--
INSERT INTO users
  (user_id, username)
OVERRIDING SYSTEM VALUE
VALUES
  (0, 'anonymous');

--
-- the role signed-out is used to control what resources
-- should be available when signed-out, and should
-- therefore only be granted to the anonymous user
--
INSERT INTO roles (role_name) VALUES ('signed-out');

SELECT api.grant_role_to_user(
  role_id := (SELECT role_id FROM roles WHERE role_name = 'signed-out'),
  user_id := 0
);

--
-- resources granted when signed-out
--
SELECT api.grant_resource_to_role(
  resource_id := resources.resource_id,
  role_id := roles.role_id
)
FROM resources
CROSS JOIN roles
WHERE resources.resource_name IN (
  'sign_up',
  'sign_in',
  'current_user',
  'user_resources',
  'verify_assertion',
  'openapi_swagger',
  'get_credential_creation_options',
  'store_credential'
)
AND roles.role_name = 'signed-out';

--
-- the signed-in role
--
INSERT INTO roles (role_name) VALUES ('signed-in');

SELECT api.grant_resource_to_role(
  resource_id := resources.resource_id,
  role_id := roles.role_id
)
FROM resources
CROSS JOIN roles
WHERE resources.resource_name IN (
  'init_credential',
  'sign_out',
  'store_credential',
  'update_credential_validity',
  'current_user',
  'user_resources',
  'user_credentials',
  'user_role_memberships',
  'openapi_swagger'
)
AND roles.role_name = 'signed-in';


--
-- grant any existing users the signed-in role,
-- except the anonymous user.
--
SELECT api.grant_role_to_user(
  role_id := roles.role_id,
  user_id := users.user_id
)
FROM users
CROSS JOIN roles
WHERE roles.role_name = 'signed-in'
AND users.user_id <> 0;

--
-- the admin role
--
INSERT INTO roles (role_name) VALUES ('admin');

SELECT api.grant_resource_to_role(
  resource_id := resources.resource_id,
  role_id := roles.role_id
)
FROM resources
CROSS JOIN roles
WHERE resources.resource_name IN (
  'create_role',
  'create_user',
  'grant_resource_to_role',
  'grant_role_to_user',
  'credentials',
  'permissions',
  'resources',
  'roles',
  'role_memberships',
  'users'
)
AND roles.role_name = 'admin';

--
-- the * role
-- all newly created functions/views in the api schema
-- after installation will be automatically added to this
-- role by the notify_ddl_postgrest() script.
--
-- this role is useful when e.g. developing locally
-- and wanting to immediately see new functions/view
-- appear in the front-end directly after have been
-- created, without any configuration at all.
--
INSERT INTO roles (role_name) VALUES ('*');

--
-- grant select access on all views in the api schema by default,
-- which also requires select access on the underlying tables
-- in the public schema.
--
GRANT SELECT ON ALL TABLES IN SCHEMA api TO web_anon;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO web_anon;
