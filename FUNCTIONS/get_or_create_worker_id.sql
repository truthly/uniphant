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
