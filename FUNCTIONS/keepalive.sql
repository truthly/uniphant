CREATE OR REPLACE FUNCTION keepalive()
RETURNS BOOLEAN AS
$$
<<fn>>
DECLARE
    process_id UUID := current_setting('application_name')::UUID;
    ok BOOLEAN;
BEGIN
    IF NOT EXISTS
    (
        SELECT 1 FROM processes
        WHERE processes.id = fn.process_id
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
        WHERE processes.id = fn.process_id
        RETURNING TRUE INTO STRICT ok;

        RETURN TRUE;
    END IF;
END;
$$ LANGUAGE plpgsql;
