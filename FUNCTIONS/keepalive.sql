CREATE OR REPLACE FUNCTION keepalive(process_id UUID)
RETURNS BOOLEAN AS
$$
DECLARE
    ok BOOLEAN;
BEGIN
    IF NOT EXISTS
    (
        SELECT 1 FROM processes
        WHERE processes.id = keepalive.process_id
    )
    THEN
        --
        -- Termination requested, killing process.
        --
        RETURN FALSE;
    ELSE
        --
        -- Process allowed to live on, update heartbeat.
        --
        UPDATE processes SET
            heartbeat_at = now()
        WHERE processes.id = keepalive.process_id
        RETURNING TRUE INTO STRICT ok;

        RETURN TRUE;
    END IF;
END;
$$ LANGUAGE plpgsql;
