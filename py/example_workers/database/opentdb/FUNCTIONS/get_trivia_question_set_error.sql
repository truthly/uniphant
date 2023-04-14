CREATE OR REPLACE FUNCTION opentdb.get_trivia_question_set_error
(
    id TEXT,
    error TEXT
)
RETURNS VOID AS
$$
DECLARE
    ok BOOLEAN;
BEGIN
    UPDATE opentdb.get_trivia_question SET
        error_at = now(),
        error = get_trivia_question_set_error.error
    WHERE opentdb.get_trivia_question.id = get_trivia_question_set_error.id
    RETURNING TRUE INTO STRICT ok;

    RETURN;
END;
$$ LANGUAGE plpgsql;
