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
