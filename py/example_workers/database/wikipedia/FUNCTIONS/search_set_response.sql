CREATE OR REPLACE FUNCTION wikipedia.search_set_response
(
    id UUID,
    response JSONB
)
RETURNS VOID AS
$$
<<fn>>
DECLARE
    ok BOOLEAN;
    answer TEXT;
BEGIN
    UPDATE wikipedia.search SET
        response = search_set_response.response,
        response_at = now()
    WHERE wikipedia.search.id = search_set_response.id
    AND wikipedia.search.response IS NULL
    RETURNING
        wikipedia.search.answer
    INTO STRICT
        answer;

    --
    -- Set the Answer for the Q&A pair.
    --
    UPDATE qa_pairs SET
        answer = fn.answer
    WHERE qa_pairs.id = search_set_response.id
    RETURNING TRUE INTO STRICT ok;

    RETURN;
END;
$$ LANGUAGE plpgsql;
