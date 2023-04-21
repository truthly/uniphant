CREATE OR REPLACE FUNCTION register_host
(
    host_id UUID,
    host_name TEXT
)
RETURNS VOID AS
$$
DECLARE
    cur_host_name TEXT;
BEGIN
    SELECT
        hosts.name
    INTO
        cur_host_name
    FROM hosts
    WHERE hosts.id = register_host.host_id;

    IF NOT FOUND THEN

        INSERT INTO hosts (id, name)
        VALUES (host_id, host_name)
        ON CONFLICT DO NOTHING;

    ELSIF cur_host_name <> host_name THEN

        UPDATE hosts SET
            name = register_host.host_name
        WHERE hosts.id = register_host.host_id;

    END IF;

    RETURN;
END;
$$ LANGUAGE plpgsql;
