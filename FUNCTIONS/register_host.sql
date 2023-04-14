CREATE OR REPLACE FUNCTION register_host
(
    host_id UUID,
    host_name TEXT
)
RETURNS VOID AS
$$
BEGIN
    INSERT INTO hosts (id, name)
    VALUES (host_id, host_name)
    ON CONFLICT DO NOTHING;

    RETURN;
END;
$$ LANGUAGE plpgsql;
