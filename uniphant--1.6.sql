-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION uniphant WITH SCHEMA public CASCADE" to load this file. \quit

CREATE SCHEMA IF NOT EXISTS api;
GRANT USAGE ON SCHEMA api TO web_anon;
GRANT USAGE ON SCHEMA webauthn TO web_anon;
GRANT web_anon TO postgrest;
CREATE OR REPLACE FUNCTION effective_domain()
RETURNS text
STABLE
LANGUAGE sql
AS $$
/*
  This function is compatible with PostgREST.

  See: https://postgrest.org/en/v7.0.0/api.html#accessing-request-headers-cookies-and-jwt-claims

  We could have used a regex to extract the host from the URL,
  but since ts_debug() has this capability, let's use it.
  The only annoyance is the special case when there is no TLD,
  such as for "http://localhost", in which case the returned alias
  is "asciiweord", which is why we need the "WHERE COUNT = 1"
  wrapper, to ensure not more than one row matched,
  which would be ambiguous.
*/
SELECT token FROM (
  SELECT token, COUNT(*) OVER ()
  FROM ts_debug(current_setting('request.header.origin', TRUE))
  WHERE alias IN ('host','asciiword')
) AS X WHERE COUNT = 1
$$;
CREATE OR REPLACE FUNCTION remote_ip()
RETURNS inet
STABLE
LANGUAGE sql
AS $$
/*
  This function is compatible with PostgREST.

  See: https://postgrest.org/en/v7.0.0/api.html#accessing-request-headers-cookies-and-jwt-claims

  If using nginx, you also need to add this line to your nginx.conf:
    proxy_set_header X_Forwarded_For $remote_addr;

  See nginx.conf in this repo for a complete example.
*/
SELECT current_setting('request.header.X_Forwarded_For', TRUE)::inet
$$;
CREATE TABLE roles (
role_id integer NOT NULL GENERATED ALWAYS AS IDENTITY,
role_name text NOT NULL,
PRIMARY KEY (role_id),
UNIQUE (role_name)
);

SELECT pg_catalog.pg_extension_config_dump('roles', '');
CREATE TABLE resources (
resource_id integer NOT NULL GENERATED ALWAYS AS IDENTITY,
resource_type text NOT NULL,
resource_name text NOT NULL,
resource_path text NOT NULL GENERATED ALWAYS AS (CASE resource_type WHEN 'function' THEN '/rpc/'||resource_name WHEN 'view' THEN '/'||resource_name END) STORED,
PRIMARY KEY (resource_id),
UNIQUE (resource_name),
CHECK (resource_name NOT LIKE '%-%') -- "-" is used as separator in HTML id tags
);

SELECT pg_catalog.pg_extension_config_dump('resources', '');
CREATE TABLE permissions (
permission_id integer NOT NULL GENERATED ALWAYS AS IDENTITY,
role_id integer NOT NULL,
resource_id integer NOT NULL,
PRIMARY KEY (permission_id),
FOREIGN KEY (role_id) REFERENCES roles,
FOREIGN KEY (resource_id) REFERENCES resources,
UNIQUE (role_id, resource_id)
);

SELECT pg_catalog.pg_extension_config_dump('permissions', '');
CREATE TABLE settings (
setting_id integer NOT NULL,
init_credential_relying_party_name text NOT NULL DEFAULT 'ACME Corporation',
init_credential_require_resident_key boolean DEFAULT TRUE,
init_credential_user_verification webauthn.user_verification_requirement NOT NULL DEFAULT 'discouraged',
init_credential_attestation webauthn.attestation_conveyance_preference NOT NULL DEFAULT 'none',
init_credential_timeout interval NOT NULL DEFAULT '5 minutes'::interval,
sign_in_user_verification webauthn.user_verification_requirement NOT NULL DEFAULT 'discouraged',
sign_in_timeout interval NOT NULL DEFAULT '5 minutes'::interval,
verify_assertion_access_token_cookie_max_age interval DEFAULT NULL::interval, -- NULL=session cookie (default)
new_credential_valid_without_confirmation boolean NOT NULL DEFAULT TRUE,
PRIMARY KEY (setting_id),
CHECK (setting_id = 1)
);

SELECT pg_catalog.pg_extension_config_dump('settings', '');

INSERT INTO settings (setting_id) VALUES (1);
CREATE TABLE users (
user_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
user_random_id bytea NOT NULL DEFAULT gen_random_bytes(64),
username text NOT NULL,
parent_user_id bigint REFERENCES users,
PRIMARY KEY (user_id)
);

SELECT pg_catalog.pg_extension_config_dump('users', '');
CREATE TABLE credentials (
credential_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
credential_bytea_id bytea NOT NULL,
device_name text NOT NULL,
user_id bigint NOT NULL,
valid boolean NOT NULL,
PRIMARY KEY (credential_id),
FOREIGN KEY (credential_bytea_id) REFERENCES webauthn.credentials,
FOREIGN KEY (user_id) REFERENCES users,
UNIQUE (credential_bytea_id)
);

SELECT pg_catalog.pg_extension_config_dump('credentials', '');
CREATE TABLE role_memberships (
role_membership_id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
user_id bigint NOT NULL,
role_id integer NOT NULL,
PRIMARY KEY (role_membership_id),
FOREIGN KEY (user_id) REFERENCES users,
FOREIGN KEY (role_id) REFERENCES roles,
UNIQUE (user_id, role_id)
);

SELECT pg_catalog.pg_extension_config_dump('role_memberships', '');
CREATE TABLE access_tokens (
access_token uuid NOT NULL DEFAULT gen_random_uuid(),
user_id bigint NOT NULL,
expire_at timestamptz,
PRIMARY KEY (access_token),
FOREIGN KEY (user_id) REFERENCES users
);

SELECT pg_catalog.pg_extension_config_dump('access_tokens', '');
CREATE TABLE openapi_swagger (
openapi_swagger_id integer NOT NULL,
openapi_swagger_doc jsonb NOT NULL,
PRIMARY KEY (openapi_swagger_id),
CHECK (openapi_swagger_id = 1)
);

SELECT pg_catalog.pg_extension_config_dump('openapi_swagger', '');
CREATE OR REPLACE FUNCTION check_resource_access(_resource_id integer)
RETURNS boolean
STABLE
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT EXISTS (
  SELECT 1
  FROM role_memberships
  JOIN permissions
    ON permissions.role_id = role_memberships.role_id
  WHERE role_memberships.user_id = user_id()
  AND permissions.resource_id = _resource_id
)
$$;
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
PERFORM set_user_id(_user_id);

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
CREATE OR REPLACE FUNCTION user_id()
RETURNS bigint
STABLE
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT current_setting('uniphant.user_id',FALSE)::bigint
$$;
CREATE OR REPLACE FUNCTION has_role(role_name text)
RETURNS boolean
STABLE
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT EXISTS (
  SELECT 1
  FROM role_memberships
  JOIN roles
    ON roles.role_id = role_memberships.role_id
  WHERE role_memberships.user_id = user_id()
  AND roles.role_name = has_role.role_name
)
$$;
CREATE OR REPLACE VIEW api.users AS
SELECT
user_id,
username,
parent_user_id
FROM users;
CREATE OR REPLACE VIEW api.current_user WITH (security_barrier) AS
SELECT
user_id,
username
FROM users
WHERE user_id = user_id();
CREATE OR REPLACE VIEW api.resources AS
SELECT
resource_id,
resource_type,
resource_name,
resource_path
FROM resources;
CREATE OR REPLACE VIEW api.roles AS
SELECT
role_id,
role_name
FROM roles;
CREATE OR REPLACE VIEW api.user_credentials WITH (security_barrier) AS
SELECT
credential_id,
device_name,
valid
FROM credentials
WHERE user_id = user_id();
CREATE OR REPLACE VIEW api.user_resources WITH (security_barrier) AS
SELECT
resource_id,
resource_type,
resource_name,
resource_path
FROM resources
WHERE check_resource_access(resource_id);
CREATE OR REPLACE VIEW api.user_role_memberships AS
SELECT
roles.role_name
FROM role_memberships
JOIN roles
  ON roles.role_id = role_memberships.role_id
WHERE role_memberships.user_id = user_id();
CREATE OR REPLACE VIEW api.permissions AS
SELECT
permissions.permission_id,
roles.role_name,
resources.resource_name
FROM permissions
JOIN roles
  ON roles.role_id = permissions.role_id
JOIN resources
  ON resources.resource_id = permissions.resource_id;
CREATE OR REPLACE VIEW api.credentials AS
SELECT
credential_id,
device_name,
user_id,
valid
FROM credentials;
CREATE OR REPLACE VIEW api.role_memberships AS
SELECT
role_memberships.role_membership_id,
role_memberships.user_id,
roles.role_name
FROM role_memberships
JOIN roles
  ON roles.role_id = role_memberships.role_id;
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
CREATE OR REPLACE FUNCTION issue_access_token(user_id bigint)
RETURNS boolean
LANGUAGE sql
AS $$
WITH
new AS (
  INSERT INTO access_tokens (user_id, expire_at)
  SELECT issue_access_token.user_id, now() + settings.verify_assertion_access_token_cookie_max_age
  FROM settings
  RETURNING access_tokens.access_token, access_tokens.expire_at
)
SELECT set_config('response.headers', format(
  '[{"Set-Cookie": "access_token=%s; path=/; HttpOnly; SameSite=Strict%s%s"}]',
  new.access_token,
  CASE WHEN effective_domain() = 'localhost' THEN '' ELSE '; Secure' END,
  '; Expires=' || to_char(new.expire_at AT TIME ZONE 'GMT','Dy, DD Mon YYYY HH:MI:SS GMT')
), TRUE) IS NOT NULL
FROM new
$$;
CREATE OR REPLACE FUNCTION set_openapi_swagger(jsonb)
RETURNS boolean
LANGUAGE sql
AS $$
INSERT INTO openapi_swagger
  (openapi_swagger_id, openapi_swagger_doc)
VALUES
  (1, $1)
ON CONFLICT ON CONSTRAINT openapi_swagger_pkey DO UPDATE SET
  openapi_swagger_doc = $1
WHERE openapi_swagger.openapi_swagger_id = 1
RETURNING TRUE
$$;
CREATE OR REPLACE FUNCTION api.init_credential(device_name text, other_device boolean)
RETURNS TABLE (
  credential_creation_options jsonb,
  other_device boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT
  webauthn.init_credential(
    challenge            := gen_random_bytes(32),
    relying_party_name   := settings.init_credential_relying_party_name,
    user_name            := users.username,
    user_id              := users.user_random_id,
    user_display_name    := init_credential.device_name,
    require_resident_key := settings.init_credential_require_resident_key,
    user_verification    := settings.init_credential_user_verification,
    attestation          := settings.init_credential_attestation,
    timeout              := settings.init_credential_timeout
  ),
  init_credential.other_device
FROM users
CROSS JOIN settings
WHERE users.user_id = user_id()
$$;
CREATE OR REPLACE FUNCTION api.store_credential(
  credential_id text,
  credential_type webauthn.credential_type,
  attestation_object text,
  client_data_json text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
DECLARE
_user_random_id bytea;
_user_id bigint;
_valid boolean;
BEGIN
_user_random_id := webauthn.store_credential(
  credential_id      := credential_id,
  credential_type    := credential_type,
  attestation_object := attestation_object,
  client_data_json   := client_data_json
);

INSERT INTO credentials
  (credential_bytea_id, device_name, user_id, valid)
SELECT
  credentials.credential_id,
  credential_challenges.user_display_name,
  users.user_id,
  CASE
    WHEN user_id() = users.user_id -- user signed-in already and is the same as the credential's user_id
    THEN TRUE
    ELSE settings.new_credential_valid_without_confirmation
  END
FROM webauthn.credentials
JOIN users
  ON users.user_random_id = credentials.user_id
JOIN webauthn.credential_challenges
  ON credential_challenges.challenge = credentials.challenge
CROSS JOIN settings
WHERE credentials.credential_id = webauthn.base64url_decode(store_credential.credential_id)
AND credentials.user_id = _user_random_id
RETURNING user_id, valid
INTO STRICT _user_id, _valid;

IF user_id() IS NOT NULL THEN
  -- user is already signed-in
  RETURN TRUE;
ELSIF _valid THEN
  -- user not signed-in,
  -- and newly created credential is immediately valid,
  -- so issue access token causing the user to be signed-in
  PERFORM issue_access_token(_user_id);
  RETURN TRUE;
END IF;

-- tell the user the credential has to be marked as valid
-- before it can be used to sign-in
RETURN FALSE;
END
$$;
CREATE OR REPLACE FUNCTION api.sign_in()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT webauthn.get_credentials(
  challenge         := gen_random_bytes(32),
  user_verification := settings.sign_in_user_verification,
  timeout           := settings.sign_in_timeout
)
FROM settings
$$;
CREATE OR REPLACE FUNCTION api.verify_assertion(
  credential_id text,
  credential_type webauthn.credential_type,
  authenticator_data text,
  client_data_json text,
  signature text,
  user_handle text
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT
  CASE credentials.valid
  WHEN TRUE
  THEN issue_access_token(users.user_id)
  END
FROM webauthn.verify_assertion(
  credential_id      := credential_id,
  credential_type    := credential_type,
  authenticator_data := authenticator_data,
  client_data_json   := client_data_json,
  signature          := signature,
  user_handle        := user_handle
)
JOIN users
  ON users.user_random_id = verify_assertion.user_id
JOIN credentials
  ON credentials.credential_bytea_id = webauthn.base64url_decode(verify_assertion.credential_id)
$$;
CREATE OR REPLACE FUNCTION api.sign_out()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
WITH del AS (
  DELETE FROM
    access_tokens
  WHERE
    access_token = NULLIF(current_setting('request.cookie.access_token', TRUE),'')::uuid
  RETURNING TRUE
)
SELECT set_config(
  'response.headers',
  format('[{"Set-Cookie": "access_token=deleted; path=/; HttpOnly; SameSite=Strict; Expires=Thu, 01 Jan 1970 00:00:01 GMT"}]'),
  TRUE
) IS NOT NULL
$$;
CREATE OR REPLACE FUNCTION api.sign_up(username text, device_name text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
DECLARE
_user_id bigint;
BEGIN

_user_id := api.create_user(username);

--
-- The first user who signs-up
-- automatically gets the admin role.
--
-- This is to simplify installations,
-- as otherwise the admin would need
-- database access to grant its user access.
--
-- (user_id 0 is the anonymous user.)
--
IF _user_id = 1 THEN
  PERFORM api.grant_role_to_user(
    role_id := (SELECT role_id FROM roles WHERE role_name = 'admin'),
    user_id := _user_id
  );
END IF;

--
-- Set user_id allowing sign_up() to be used
-- in conjunction with init_credential()
-- that calls user_id().
--
PERFORM set_user_id(_user_id);

PERFORM issue_access_token(_user_id);

RETURN (SELECT credential_creation_options FROM api.init_credential(device_name, FALSE));

END
$$;
CREATE OR REPLACE FUNCTION api.get_credential_creation_options(challenge text)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT webauthn.get_credential_creation_options(webauthn.base64url_decode(challenge))
$$;
CREATE OR REPLACE FUNCTION api.create_role(role_name text)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
INSERT INTO roles
  (role_name)
VALUES
  (role_name)
RETURNING role_id
$$;
CREATE OR REPLACE FUNCTION api.grant_role_to_user(
  role_id integer,
  user_id bigint
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
INSERT INTO role_memberships
  (user_id, role_id)
VALUES
  (user_id, role_id)
RETURNING TRUE
$$;
CREATE OR REPLACE FUNCTION api.grant_resource_to_role(
  resource_id integer,
  role_id integer
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
INSERT INTO permissions
  (role_id, resource_id)
VALUES
  (role_id, resource_id)
RETURNING TRUE
$$;
CREATE OR REPLACE FUNCTION api.create_user(username text)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
DECLARE
_user_id bigint;
BEGIN
INSERT INTO users
  (username, parent_user_id)
VALUES
  (username, user_id())
RETURNING user_id
INTO STRICT _user_id;

PERFORM api.grant_role_to_user(
  role_id := (SELECT role_id FROM roles WHERE role_name = 'signed-in'),
  user_id := _user_id
);

RETURN _user_id;
END
$$;
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
CREATE OR REPLACE FUNCTION api.openapi_swagger()
RETURNS jsonb
STABLE
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT jsonb_set(openapi_swagger_doc,'{paths}',jsonb_object_agg(path, openapi_swagger_doc->'paths'->path))
FROM openapi_swagger
CROSS JOIN jsonb_object_keys(openapi_swagger_doc->'paths') AS path
JOIN resources ON resources.resource_path = path
              AND check_resource_access(resources.resource_id)
GROUP BY openapi_swagger_doc
$$;
CREATE OR REPLACE FUNCTION notify_ddl_postgrest()
RETURNS event_trigger
LANGUAGE plpgsql
AS $$
BEGIN
NOTIFY ddl_command_end;
END
$$;

CREATE EVENT TRIGGER ddl_postgrest ON ddl_command_end
EXECUTE PROCEDURE public.notify_ddl_postgrest();
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
CREATE TABLE hosts
(
    id UUID NOT NULL,
    name text NOT NULL,

    PRIMARY KEY (id)
);
CREATE TABLE worker_types
(
    worker_type TEXT NOT NULL,

    PRIMARY KEY (worker_type)
);
CREATE TABLE workers
(
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    host_id UUID NOT NULL,
    worker_type TEXT NOT NULL,

    PRIMARY KEY (id),
    FOREIGN KEY (host_id) REFERENCES hosts,
    FOREIGN KEY (worker_type) REFERENCES worker_types
);
CREATE TABLE processes
(
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL,
    heartbeat_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (id),
    FOREIGN KEY (worker_id) REFERENCES workers,
    UNIQUE (worker_id)
);
CREATE OR REPLACE FUNCTION register_host
(
    host_id UUID,
    host_name TEXT
)
RETURNS VOID AS
$$
BEGIN
    INSERT INTO hosts (id, name)
    VALUES (host_id, host_name)
    ON CONFLICT DO NOTHING;

    RETURN;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION register_process
(
    worker_id UUID
)
RETURNS VOID AS
$$
<<fn>>
DECLARE
    process_id UUID := current_setting('application_name')::UUID;
    ok BOOLEAN;
BEGIN
    IF EXISTS
    (
        SELECT 1 FROM processes
        WHERE processes.id = fn.process_id
        AND processes.worker_id = register_process.worker_id
    ) THEN
        RETURN;
    END IF;

    INSERT INTO processes (id, worker_id)
    VALUES (process_id, worker_id)
    RETURNING TRUE INTO STRICT ok;

    RETURN;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION keepalive()
RETURNS BOOLEAN AS
$$
<<fn>>
DECLARE
    process_id UUID := current_setting('application_name')::UUID;
    ok BOOLEAN;
BEGIN
    IF NOT EXISTS
    (
        SELECT 1 FROM processes
        WHERE processes.id = fn.process_id
    )
    THEN
        --
        -- Termination requested, killing process.
        --
        RETURN FALSE;
    ELSE
        --
        -- Process allowed to live on, update heartbeat.
        --
        UPDATE processes SET
            heartbeat_at = now()
        WHERE processes.id = fn.process_id
        RETURNING TRUE INTO STRICT ok;

        RETURN TRUE;
    END IF;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION disconnect()
RETURNS VOID AS
$$
DECLARE
    process_id UUID := current_setting('application_name')::UUID;
BEGIN
    DELETE FROM processes WHERE id = process_id;

    RETURN;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION get_or_create_worker_id
(
    OUT worker_id UUID,
    host_id UUID,
    worker_type TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
BEGIN
    --
    -- Acquire a lock on the hosts table to prevent race conditions.
    --
    PERFORM 1 FROM hosts
    WHERE hosts.id = get_or_create_worker_id.host_id
    FOR UPDATE;

    --
    -- Create a worker if no worker exists
    -- for the given host_id and worker_type.
    --
    IF NOT EXISTS
    (
        SELECT 1
        FROM workers
        WHERE workers.host_id = get_or_create_worker_id.host_id
        AND workers.worker_type = get_or_create_worker_id.worker_type
    )
    THEN
        INSERT INTO worker_types
            (worker_type)
        VALUES
            (worker_type)
        ON CONFLICT DO NOTHING;

        INSERT INTO workers
            (host_id, worker_type)
        VALUES
            (host_id, worker_type);
    END IF;

    SELECT
        workers.id
    INTO STRICT
        worker_id
    FROM workers
    WHERE workers.host_id = get_or_create_worker_id.host_id
    AND workers.worker_type = get_or_create_worker_id.worker_type;

    RETURN;
END
$$;
CREATE OR REPLACE FUNCTION scale_up
(
    host_id UUID,
    worker_type TEXT,
    num_workers INTEGER
)
RETURNS SETOF UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
    INSERT INTO workers
    (
        host_id,
        worker_type
    )
    SELECT
        scale_up.host_id,
        scale_up.worker_type
    FROM generate_series(1,num_workers)
    RETURNING workers.id;
$$;
CREATE OR REPLACE FUNCTION scale_down
(
    host_id UUID,
    worker_type TEXT,
    num_workers INTEGER
)
RETURNS SETOF UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
    WITH
    worker_heartbeat_ranking AS
    (
        SELECT
            workers.id AS worker_id,
            ROW_NUMBER() OVER (ORDER BY processes.heartbeat_at NULLS FIRST)
        FROM workers
        LEFT JOIN processes ON processes.worker_id = workers.id
        WHERE workers.host_id = scale_down.host_id
        AND workers.worker_type = scale_down.worker_type
    ),
    workers_to_remove AS
    (
        SELECT
            worker_id
        FROM worker_heartbeat_ranking
        WHERE ROW_NUMBER <= num_workers
    )
    DELETE FROM workers
    USING workers_to_remove
    WHERE workers_to_remove.worker_id = workers.id
    RETURNING id
$$;
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
