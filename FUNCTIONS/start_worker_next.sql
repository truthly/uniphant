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
