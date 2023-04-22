CREATE OR REPLACE FUNCTION delete_process(process_id UUID)
RETURNS VOID AS
$$
DECLARE
    ok BOOLEAN;
BEGIN
    DELETE FROM processes
    WHERE processes.id = delete_process.process_id
    RETURNING TRUE INTO STRICT ok;

    RETURN;
END;
$$ LANGUAGE plpgsql;
