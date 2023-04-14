CREATE TABLE wikipedia.search
(
    id UUID NOT NULL,
    process_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    error text,
    error_at TIMESTAMPTZ,
    response JSONB,
    response_at TIMESTAMPTZ,
    question TEXT NOT NULL,
    answer TEXT GENERATED ALWAYS AS (response->'query'->'search'->0->>'snippet') STORED,

    PRIMARY KEY (id),
    FOREIGN KEY (id) REFERENCES qa_pairs,
    CHECK ((error IS NULL) = (error_at IS NULL)),
    CHECK ((response IS NULL) = (response_at IS NULL))
);

CREATE INDEX ON wikipedia.search (id)
    WHERE response_at IS NULL
    AND error_at IS NULL;
