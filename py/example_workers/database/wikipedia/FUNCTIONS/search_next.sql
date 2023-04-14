CREATE OR REPLACE FUNCTION wikipedia.search_next(
    OUT id UUID,
    OUT question TEXT
)
RETURNS RECORD AS
$$
<<fn>>
DECLARE
    process_id UUID := current_setting('application_name')::UUID;
    ok BOOLEAN;
BEGIN
    SELECT
        wikipedia.search.id,
        wikipedia.search.question
    INTO
        id,
        question
    FROM wikipedia.search
    WHERE wikipedia.search.response_at IS NULL
    AND wikipedia.search.error_at IS NULL
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    UPDATE wikipedia.search SET
        process_id = fn.process_id
    WHERE wikipedia.search.id = search_next.id
    RETURNING TRUE INTO STRICT ok;

    RETURN;
END;
$$ LANGUAGE plpgsql;
