EXTENSION = uniphant
DATA = \
	uniphant--1.0.sql \
	uniphant--1.0--1.1.sql \
	uniphant--1.1.sql \
	uniphant--1.1--1.2.sql \
	uniphant--1.2.sql \
	uniphant--1.2--1.3.sql \
	uniphant--1.3.sql \
	uniphant--1.3--1.4.sql \
	uniphant--1.4.sql \
	uniphant--1.4--1.5.sql \
	uniphant--1.5.sql \
	uniphant--1.5--1.6.sql \
	uniphant--1.6.sql

REGRESS = test
EXTRA_CLEAN = uniphant--1.6.sql uniphant--1.5--1.6.sql

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

all: uniphant--1.6.sql uniphant--1.5--1.6.sql

SQL_SRC = \
	header.sql \
	FUNCTIONS/effective_domain.sql \
	FUNCTIONS/remote_ip.sql \
	TABLES/roles.sql \
	TABLES/resources.sql \
	TABLES/permissions.sql \
	TABLES/settings.sql \
	TABLES/users.sql \
	TABLES/credentials.sql \
	TABLES/role_memberships.sql \
	TABLES/access_tokens.sql \
	TABLES/openapi_swagger.sql \
	FUNCTIONS/check_resource_access.sql \
	FUNCTIONS/auth.sql \
	FUNCTIONS/set_user_id.sql \
	FUNCTIONS/user_id.sql \
	FUNCTIONS/has_role.sql \
	VIEWS/api/users.sql \
	VIEWS/api/current_user.sql \
	VIEWS/api/resources.sql \
	VIEWS/api/roles.sql \
	VIEWS/api/user_credentials.sql \
	VIEWS/api/user_resources.sql \
	VIEWS/api/user_role_memberships.sql \
	VIEWS/api/permissions.sql \
	VIEWS/api/credentials.sql \
	VIEWS/api/role_memberships.sql \
	FUNCTIONS/register_resource.sql \
	FUNCTIONS/issue_access_token.sql \
	FUNCTIONS/set_openapi_swagger.sql \
	FUNCTIONS/api/init_credential.sql \
	FUNCTIONS/api/store_credential.sql \
	FUNCTIONS/api/sign_in.sql \
	FUNCTIONS/api/verify_assertion.sql \
	FUNCTIONS/api/sign_out.sql \
	FUNCTIONS/api/sign_up.sql \
	FUNCTIONS/api/get_credential_creation_options.sql \
	FUNCTIONS/api/create_role.sql \
	FUNCTIONS/api/grant_role_to_user.sql \
	FUNCTIONS/api/grant_resource_to_role.sql \
	FUNCTIONS/api/create_user.sql \
	FUNCTIONS/api/update_credential_validity.sql \
	FUNCTIONS/api/openapi_swagger.sql \
	FUNCTIONS/notify_ddl_postgrest.sql \
	FUNCTIONS/auto_add_new_resources.sql \
	TABLES/hosts.sql \
	TABLES/worker_types.sql \
	TABLES/workers.sql \
	TABLES/processes.sql \
	FUNCTIONS/register_host.sql \
	FUNCTIONS/register_worker.sql \
	FUNCTIONS/register_process.sql \
	FUNCTIONS/keepalive_process.sql \
	FUNCTIONS/delete_process.sql \
	FUNCTIONS/get_or_create_worker_id.sql \
	FUNCTIONS/scale_up.sql \
	FUNCTIONS/scale_down.sql \
	FUNCTIONS/get_process.sql \
	FUNCTIONS/terminate_process.sql \
	FUNCTIONS/start_worker_next.sql \
	FUNCTIONS/kill_worker_next.sql \
	FUNCTIONS/ping_worker_next.sql \
	footer.sql

uniphant--1.6.sql: $(SQL_SRC)
	cat $^ > $@

SQL_SRC = \
	FUNCTIONS/remote_ip.sql \
	TABLES/hosts.sql \
	TABLES/worker_types.sql \
	TABLES/workers.sql \
	TABLES/processes.sql \
	FUNCTIONS/register_host.sql \
	FUNCTIONS/register_worker.sql \
	FUNCTIONS/register_process.sql \
	FUNCTIONS/keepalive_process.sql \
	FUNCTIONS/delete_process.sql \
	FUNCTIONS/get_or_create_worker_id.sql \
	FUNCTIONS/scale_up.sql \
	FUNCTIONS/scale_down.sql \
	FUNCTIONS/get_process.sql \
	FUNCTIONS/terminate_process.sql \
	FUNCTIONS/start_worker_next.sql \
	FUNCTIONS/kill_worker_next.sql \
	FUNCTIONS/ping_worker_next.sql

uniphant--1.5--1.6.sql: $(SQL_SRC)
	cat $^ > $@
