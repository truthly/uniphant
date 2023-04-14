CREATE OR REPLACE FUNCTION opentdb.get_trivia_question_set_response
(
    id UUID,
    response JSONB
)
RETURNS VOID AS
$$
<<fn>>
DECLARE
    ok BOOLEAN;
    question TEXT;
BEGIN
    UPDATE opentdb.get_trivia_question SET
        response = get_trivia_question_set_response.response,
        response_at = now()
    WHERE opentdb.get_trivia_question.id = get_trivia_question_set_response.id
    AND opentdb.get_trivia_question.response IS NULL
    RETURNING
        opentdb.get_trivia_question.question
    INTO STRICT
        question;

    --
    -- Set the Question for the Q&A pair.
    --
    UPDATE qa_pairs SET
        question = fn.question
    WHERE qa_pairs.id = get_trivia_question_set_response.id
    RETURNING TRUE INTO STRICT ok;

    --
    -- Init API call to Wikipedia to search for an answer to the question.
    --
    INSERT INTO wikipedia.search
        (id, question)
    VALUES
        (id, question);

    RETURN;
END;
$$ LANGUAGE plpgsql;
