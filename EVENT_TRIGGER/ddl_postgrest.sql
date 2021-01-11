--
-- api user can't create event trigger,
-- therefore, reset role to gain role
-- of installation script user
--
RESET ROLE;

CREATE EVENT TRIGGER ddl_postgrest ON ddl_command_end
EXECUTE PROCEDURE notify_ddl_postgrest();

--
-- set role to api again so it will get the ownership
-- of objects created
--
SET ROLE api;
