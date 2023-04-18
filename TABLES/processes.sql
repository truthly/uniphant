CREATE TABLE processes
(
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL,
    heartbeat_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (id),
    FOREIGN KEY (worker_id) REFERENCES workers,
    UNIQUE (worker_id)
);
