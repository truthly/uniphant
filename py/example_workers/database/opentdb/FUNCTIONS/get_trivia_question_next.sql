CREATE OR REPLACE FUNCTION opentdb.get_trivia_question_next(process_id UUID)
RETURNS UUID AS
$$
<<fn>>
DECLARE
    id UUID;
    ok BOOLEAN;
BEGIN
    SELECT
        opentdb.get_trivia_question.id
    INTO
        id
    FROM opentdb.get_trivia_question
    WHERE opentdb.get_trivia_question.process_id IS NULL
    AND opentdb.get_trivia_question.response_at IS NULL
    AND opentdb.get_trivia_question.error_at IS NULL
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    UPDATE opentdb.get_trivia_question SET
        process_id = get_trivia_question_next.process_id
    WHERE opentdb.get_trivia_question.id = fn.id
    RETURNING TRUE INTO STRICT ok;

    RETURN id;
END;
$$ LANGUAGE plpgsql;
