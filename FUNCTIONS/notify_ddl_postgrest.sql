CREATE OR REPLACE FUNCTION notify_ddl_postgrest()
RETURNS event_trigger
LANGUAGE plpgsql
AS $$
BEGIN
NOTIFY ddl_command_end;
END
$$;
