CREATE TABLE qa_pairs
(
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    question TEXT,
    answer TEXT,

    PRIMARY KEY (id)
);
