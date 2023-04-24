CREATE OR REPLACE FUNCTION keepalive(process_id UUID)
RETURNS BOOLEAN AS
$$
DECLARE
    termination_requested BOOLEAN;
BEGIN
    UPDATE processes SET
        heartbeat_at = now()
    WHERE processes.id = keepalive.process_id
    RETURNING processes.termination_requested
    INTO STRICT termination_requested;
    --
    -- Process should continue to run as long as
    -- termination has not been requested.
    --
    RETURN NOT termination_requested;
END;
$$ LANGUAGE plpgsql;
