CREATE OR REPLACE FUNCTION request_process_termination(process_id UUID)
RETURNS VOID AS
$$
DECLARE
    ok BOOLEAN;
BEGIN
    UPDATE processes
    SET termination_requested = TRUE
    WHERE processes.id = request_process_termination.process_id
    RETURNING TRUE INTO STRICT ok;

    RETURN;
END;
$$ LANGUAGE plpgsql;
