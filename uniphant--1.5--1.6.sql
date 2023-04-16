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
    FOREIGN KEY (worker_id) REFERENCES workers
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
    host_id UUID,
    host_name TEXT,
    worker_id UUID,
    worker_type TEXT
)
RETURNS VOID AS
$$
DECLARE
    process_id UUID := current_setting('application_name')::UUID;
BEGIN
    INSERT INTO hosts (id, name)
    VALUES (host_id, host_name)
    ON CONFLICT DO NOTHING;

    INSERT INTO worker_types (worker_type)
    VALUES (worker_type)
    ON CONFLICT DO NOTHING;

    INSERT INTO workers (id, host_id, worker_type)
    VALUES (worker_id, host_id, worker_type)
    ON CONFLICT DO NOTHING;

    DELETE FROM processes
    WHERE processes.worker_id = register_process.worker_id;

    INSERT INTO processes (id, worker_id)
    VALUES (process_id, worker_id)
    ON CONFLICT DO NOTHING;

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
CREATE OR REPLACE FUNCTION ensure_worker_exists_and_get_ids
(
    host_id UUID,
    worker_type TEXT
)
RETURNS SETOF UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
<<fn>>
DECLARE
    worker_id UUID;
BEGIN
    --
    -- Acquire a lock on the hosts table to prevent race conditions.
    --
    PERFORM 1 FROM hosts
    WHERE hosts.id = ensure_worker_exists_and_get_ids.host_id
    FOR UPDATE;

    --
    -- Create a worker if no worker exists
    -- for the given host_id and worker_type.
    --
    IF NOT EXISTS
    (
        SELECT 1
        FROM workers
        WHERE workers.host_id = ensure_worker_exists_and_get_ids.host_id
        AND workers.worker_type = ensure_worker_exists_and_get_ids.worker_type
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

    --
    -- Return the worker_ids of existing workers
    -- for the given host_id and worker_type.
    --
    RETURN QUERY
    SELECT
        workers.id
    FROM workers
    WHERE workers.host_id = ensure_worker_exists_and_get_ids.host_id
    AND workers.worker_type = ensure_worker_exists_and_get_ids.worker_type;
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
