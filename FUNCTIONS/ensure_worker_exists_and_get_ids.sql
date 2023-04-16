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
