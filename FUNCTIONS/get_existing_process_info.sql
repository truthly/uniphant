CREATE OR REPLACE FUNCTION get_existing_process_info
(
    OUT process_id UUID,
    OUT pid INTEGER,
    host_id UUID,
    worker_id UUID
)
RETURNS RECORD AS
$$
DECLARE
    cur_host_id UUID;
BEGIN
    IF num_nulls(host_id, worker_id) > 0 THEN
        RAISE EXCEPTION 'Both host_id and worker_id must be non-null values.';
    END IF;

    SELECT
        processes.id,
        processes.pid,
        workers.host_id
    INTO
        process_id,
        pid,
        cur_host_id
    FROM processes
    JOIN workers ON workers.id = processes.worker_id
    WHERE workers.id = get_existing_process_info.worker_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF cur_host_id <> host_id THEN
        RAISE EXCEPTION 'Mismatch in host_id: worker_id % has pid % on host %, expected host %.',
            worker_id, pid, cur_host_id, host_id;
    END IF;

    RETURN;
END;
$$ LANGUAGE plpgsql;
