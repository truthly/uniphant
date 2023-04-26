CREATE TABLE workers
(
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    host_id UUID NOT NULL,
    worker_type TEXT NOT NULL,
    command TEXT,

    PRIMARY KEY (id),
    FOREIGN KEY (host_id) REFERENCES hosts,
    FOREIGN KEY (worker_type) REFERENCES worker_types
);
