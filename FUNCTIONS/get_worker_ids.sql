CREATE OR REPLACE FUNCTION get_worker_ids
(
    host_id UUID,
    worker_type TEXT
)
RETURNS SETOF UUID
STABLE
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
SELECT
    workers.id
FROM workers
WHERE workers.host_id = get_worker_ids.host_id
AND workers.worker_type = get_worker_ids.worker_type
$$;
