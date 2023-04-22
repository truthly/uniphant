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
