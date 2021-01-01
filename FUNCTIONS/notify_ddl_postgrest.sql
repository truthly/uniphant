CREATE OR REPLACE FUNCTION notify_ddl_postgrest()
RETURNS event_trigger
LANGUAGE plpgsql
AS $$
BEGIN
NOTIFY ddl_command_end;
END
$$;

CREATE EVENT TRIGGER ddl_postgrest ON ddl_command_end
EXECUTE PROCEDURE public.notify_ddl_postgrest();
