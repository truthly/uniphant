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
