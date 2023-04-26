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
