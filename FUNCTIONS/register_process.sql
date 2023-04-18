CREATE OR REPLACE FUNCTION register_process
(
    worker_id UUID
)
RETURNS VOID AS
$$
<<fn>>
DECLARE
    process_id UUID := current_setting('application_name')::UUID;
    ok BOOLEAN;
BEGIN
    IF EXISTS
    (
        SELECT 1 FROM processes
        WHERE processes.id = fn.process_id
        AND processes.worker_id = register_process.worker_id
    ) THEN
        RETURN;
    END IF;

    INSERT INTO processes (id, worker_id)
    VALUES (process_id, worker_id)
    RETURNING TRUE INTO STRICT ok;

    RETURN;
END;
$$ LANGUAGE plpgsql;
