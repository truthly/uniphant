CREATE OR REPLACE FUNCTION gen_qa_pair()
RETURNS UUID AS
$$
<<fn>>
DECLARE
    id UUID;
    ok BOOLEAN;
BEGIN
    --
    -- Init a new empty Q&A pair and get the id.
    --
    INSERT INTO qa_pairs DEFAULT VALUES RETURNING qa_pairs.id INTO STRICT id;

    --
    -- Init API call to Open Trivia's public API to get a question.
    --
    -- Upon completion, the response handler
    --
    --     opentdb.get_trivia_question_set_response()
    --
    -- will init an API call to Wikipedia to get an answer to the question.
    --
    INSERT INTO opentdb.get_trivia_question (id) VALUES (id);

    RETURN id;
END;
$$ LANGUAGE plpgsql;
