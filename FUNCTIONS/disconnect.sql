CREATE OR REPLACE FUNCTION disconnect()
RETURNS VOID AS
$$
DECLARE
    process_id UUID := current_setting('application_name')::UUID;
BEGIN
    DELETE FROM processes WHERE id = process_id;

    RETURN;
END;
$$ LANGUAGE plpgsql;
