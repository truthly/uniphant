CREATE OR REPLACE FUNCTION register_process
(
    host_id UUID,
    host_name TEXT,
    worker_id UUID,
    worker_type TEXT
)
RETURNS VOID AS
$$
DECLARE
    process_id UUID := current_setting('application_name')::UUID;
BEGIN
    INSERT INTO hosts (id, name)
    VALUES (host_id, host_name)
    ON CONFLICT DO NOTHING;

    INSERT INTO worker_types (worker_type)
    VALUES (worker_type)
    ON CONFLICT DO NOTHING;

    INSERT INTO workers (id, host_id, worker_type)
    VALUES (worker_id, host_id, worker_type)
    ON CONFLICT DO NOTHING;

    DELETE FROM processes
    WHERE processes.worker_id = register_process.worker_id;

    INSERT INTO processes (id, worker_id)
    VALUES (process_id, worker_id)
    ON CONFLICT DO NOTHING;

    RETURN;
END;
$$ LANGUAGE plpgsql;
