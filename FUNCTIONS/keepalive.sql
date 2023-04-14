CREATE OR REPLACE FUNCTION keepalive
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

    INSERT INTO processes (id, worker_id)
    VALUES (process_id, worker_id)
    ON CONFLICT (id)
    DO UPDATE SET heartbeat_at = now();

    RETURN;
END;
$$ LANGUAGE plpgsql;
