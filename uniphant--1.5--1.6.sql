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
    command TEXT,

    PRIMARY KEY (id),
    FOREIGN KEY (host_id) REFERENCES hosts,
    FOREIGN KEY (worker_type) REFERENCES worker_types
);
CREATE TABLE processes
(
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL,
    pid INTEGER NOT NULL,
    heartbeat_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    termination_requested BOOLEAN NOT NULL DEFAULT FALSE,

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
DECLARE
    cur_host_name TEXT;
BEGIN
    SELECT
        hosts.name
    INTO
        cur_host_name
    FROM hosts
    WHERE hosts.id = register_host.host_id;

    IF NOT FOUND THEN

        INSERT INTO hosts (id, name)
        VALUES (host_id, host_name)
        ON CONFLICT DO NOTHING;

    ELSIF cur_host_name <> host_name THEN

        UPDATE hosts SET
            name = register_host.host_name
        WHERE hosts.id = register_host.host_id;

    END IF;

    RETURN;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION register_worker
(
    worker_id UUID,
    worker_type TEXT,
    host_id UUID,
    host_name TEXT
)
RETURNS VOID AS
$$
DECLARE
    ok BOOLEAN;
BEGIN
    PERFORM register_host(host_id, host_name);

    INSERT INTO worker_types
        (worker_type)
    VALUES
        (worker_type)
    ON CONFLICT DO NOTHING;

    IF EXISTS
    (
        SELECT 1 FROM workers WHERE workers.id = register_worker.worker_id
    )
    THEN
        IF EXISTS
        (
            SELECT 1 FROM workers
            WHERE workers.id = register_worker.worker_id
            AND workers.worker_type = register_worker.worker_type
            AND workers.host_id = register_worker.host_id
        )
        THEN
            RETURN;
        ELSE
            RAISE EXCEPTION 'Inconsistent data for existing worker with id %', worker_id;
        END IF;
    END IF;

    INSERT INTO workers
        (id, host_id, worker_type)
    VALUES
        (worker_id, host_id, worker_type)
    RETURNING TRUE INTO STRICT ok;

    RETURN;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION register_process
(
    process_id UUID,
    worker_id UUID,
    pid INTEGER
)
RETURNS VOID AS
$$
DECLARE
    ok BOOLEAN;
BEGIN
    --
    -- Explicitly non-idempotent to counteract the hypothetical risk of multiple process instances
    -- erroneously claiming exclusive ownership of the same process_id, which could potentially
    -- stem from unintended forking or threading scenarios within the application's execution environment.
    INSERT INTO processes (id, worker_id, pid)
    VALUES (process_id, worker_id, pid)
    RETURNING TRUE INTO STRICT ok;

    RETURN;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION keepalive_process(process_id UUID)
RETURNS BOOLEAN AS
$$
DECLARE
    termination_requested BOOLEAN;
BEGIN
    UPDATE processes SET
        heartbeat_at = now()
    WHERE processes.id = keepalive_process.process_id
    RETURNING processes.termination_requested
    INTO STRICT termination_requested;
    --
    -- Process should continue to run as long as
    -- termination has not been requested.
    --
    RETURN NOT termination_requested;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION delete_process(process_id UUID)
RETURNS VOID AS
$$
DECLARE
    ok BOOLEAN;
BEGIN
    DELETE FROM processes
    WHERE processes.id = delete_process.process_id
    RETURNING TRUE INTO STRICT ok;

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
CREATE OR REPLACE FUNCTION get_process
(
    OUT process_id UUID,
    worker_id UUID
)
RETURNS UUID AS
$$
BEGIN
    IF worker_id IS NULL THEN
        RAISE EXCEPTION 'worker_id must not be NULL';
    END IF;
    IF NOT EXISTS
    (
        SELECT 1
        FROM processes
        WHERE processes.worker_id = get_process.worker_id
    )
    THEN
        RETURN;
    ELSE
        SELECT
            processes.id
        INTO STRICT
            process_id
        FROM processes
        WHERE processes.worker_id = get_process.worker_id;
    END IF;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION terminate_process(process_id UUID)
RETURNS VOID AS
$$
DECLARE
    ok BOOLEAN;
BEGIN
    UPDATE processes
    SET termination_requested = TRUE
    WHERE processes.id = terminate_process.process_id
    RETURNING TRUE INTO STRICT ok;

    RETURN;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION start_worker_next
(
    OUT worker_id UUID,
    OUT worker_type TEXT,
    host_id UUID
)
RETURNS RECORD
LANGUAGE plpgsql AS
$$
DECLARE
    ok BOOLEAN;
BEGIN
    SELECT
        workers.id,
        workers.worker_type
    INTO
        worker_id,
        worker_type
    FROM workers
    WHERE workers.host_id = start_worker_next.host_id
    AND workers.command = 'start'
    LIMIT 1
    FOR UPDATE SKIP LOCKED;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    UPDATE workers
    SET command = NULL
    WHERE workers.id = start_worker_next.worker_id
    RETURNING TRUE INTO STRICT ok;

    RETURN;
END
$$;
CREATE OR REPLACE FUNCTION kill_worker_next
(
    OUT worker_id UUID,
    OUT worker_type TEXT,
    OUT command TEXT,
    OUT pid INTEGER,
    host_id UUID
)
RETURNS RECORD
LANGUAGE plpgsql AS
$$
DECLARE
    ok BOOLEAN;
BEGIN
    SELECT
        workers.id,
        workers.worker_type,
        workers.command,
        processes.pid
    INTO
        worker_id,
        worker_type,
        command,
        pid
    FROM workers
    JOIN processes ON processes.worker_id = workers.id
    WHERE workers.host_id = kill_worker_next.host_id
    AND workers.command IN ('term','kill')
    LIMIT 1
    FOR UPDATE SKIP LOCKED;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    UPDATE workers
    SET command = NULL
    WHERE workers.id = kill_worker_next.worker_id
    RETURNING TRUE INTO STRICT ok;

    RETURN;
END
$$;
CREATE OR REPLACE FUNCTION ping_worker_next
(
    OUT worker_id UUID,
    OUT worker_type TEXT,
    OUT process_id UUID,
    OUT pid INTEGER,
    host_id UUID
)
RETURNS RECORD
LANGUAGE plpgsql AS
$$
DECLARE
    ok BOOLEAN;
BEGIN
    SELECT
        workers.id,
        workers.worker_type,
        processes.id,
        processes.pid
    INTO
        worker_id,
        worker_type,
        process_id,
        pid
    FROM workers
    JOIN processes ON processes.worker_id = workers.id
    WHERE workers.host_id = ping_worker_next.host_id
    AND workers.command = 'ping'
    LIMIT 1
    FOR UPDATE SKIP LOCKED;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    UPDATE workers
    SET command = NULL
    WHERE workers.id = ping_worker_next.worker_id
    RETURNING TRUE INTO STRICT ok;

    RETURN;
END
$$;
