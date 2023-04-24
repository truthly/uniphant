CREATE OR REPLACE FUNCTION get_worker_process_id
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
        WHERE processes.worker_id = get_worker_process_id.worker_id
    )
    THEN
        RETURN;
    ELSE
        SELECT
            processes.id
        INTO STRICT
            process_id
        FROM processes
        WHERE processes.worker_id = get_worker_process_id.worker_id;
    END IF;
END;
$$ LANGUAGE plpgsql;
