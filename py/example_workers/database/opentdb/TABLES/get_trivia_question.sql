CREATE TABLE opentdb.get_trivia_question
(
    id UUID NOT NULL,
    process_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    error text,
    error_at TIMESTAMPTZ,
    response JSONB,
    response_at TIMESTAMPTZ,
    question TEXT GENERATED ALWAYS AS (response->'results'->0->>'question') STORED,

    PRIMARY KEY (id),
    FOREIGN KEY (id) REFERENCES qa_pairs,
    CHECK ((error IS NULL) = (error_at IS NULL)),
    CHECK ((response IS NULL) = (response_at IS NULL))
);

CREATE INDEX ON opentdb.get_trivia_question (id)
    WHERE response_at IS NULL
    AND error_at IS NULL;
