CREATE OR REPLACE FUNCTION wikipedia.search_set_error
(
    id TEXT,
    error TEXT
)
RETURNS VOID AS
$$
DECLARE
    ok BOOLEAN;
BEGIN
    UPDATE wikipedia.search SET
        error_at = now(),
        error = search_set_error.error
    WHERE wikipedia.search.id = search_set_error.id
    RETURNING TRUE INTO STRICT ok;

    RETURN;
END;
$$ LANGUAGE plpgsql;
