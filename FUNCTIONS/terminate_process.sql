CREATE OR REPLACE FUNCTION terminate_process(process_id UUID)
RETURNS VOID AS
$$
DECLARE
    ok BOOLEAN;
BEGIN
    UPDATE processes
    SET termination_requested = TRUE
    WHERE processes.id = terminate_process.process_id
    RETURNING TRUE INTO STRICT ok;

    RETURN;
END;
$$ LANGUAGE plpgsql;
