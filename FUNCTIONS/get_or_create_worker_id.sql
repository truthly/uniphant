CREATE OR REPLACE FUNCTION get_or_create_worker_id
(
    host_id UUID,
    worker_type TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
<<fn>>
DECLARE
    worker_ids UUID[];
    worker_id UUID;
BEGIN
    PERFORM 1 FROM hosts
    WHERE hosts.id = get_or_create_worker_id.host_id
    FOR UPDATE;

    SELECT
        array_agg(workers.id)
    INTO
        worker_ids
    FROM workers
    WHERE workers.host_id = get_or_create_worker_id.host_id
    AND workers.worker_type = get_or_create_worker_id.worker_type;

    IF cardinality(worker_ids) = 1 THEN
        worker_id := worker_ids[1];
    ELSIF cardinality(worker_ids) > 1 THEN
        RAISE EXCEPTION 'There are multiple worker_ids of the worker_type for the host_id. Please specify the desired worker_id.';
    ELSIF worker_ids IS NULL THEN
        INSERT INTO worker_types
            (worker_type)
        VALUES
            (worker_type)
        ON CONFLICT DO NOTHING;

        INSERT INTO workers
            (host_id, worker_type)
        VALUES
            (host_id, worker_type)
        RETURNING workers.id
        INTO STRICT fn.worker_id;
    ELSE
        RAISE EXCEPTION 'Unreachable';
    END IF;

    RETURN worker_id;
END
$$;
