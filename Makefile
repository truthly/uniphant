EXTENSION = uniphant
DATA = uniphant--1.2.sql uniphant--1.1--1.2.sql

REGRESS = test
EXTRA_CLEAN = uniphant--1.2.sql uniphant--1.1--1.2.sql

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

all: uniphant--1.2.sql uniphant--1.1--1.2.sql

SQL_SRC = \
  complain_header.sql \
  create_schema_grant.sql \
  FUNCTIONS/effective_domain.sql \
  FUNCTIONS/remote_ip.sql \
  TABLES/settings.sql \
  TABLES/users.sql \
	TABLES/access_tokens.sql \
	FUNCTIONS/issue_access_token.sql \
	FUNCTIONS/user_id.sql \
	FUNCTIONS/api/init_credential.sql \
  FUNCTIONS/api/make_credential.sql \
  FUNCTIONS/api/get_credentials.sql \
  FUNCTIONS/api/verify_assertion.sql \
	FUNCTIONS/api/is_signed_in.sql \
	FUNCTIONS/api/sign_out.sql \
	FUNCTIONS/api/sign_up.sql \
	FUNCTIONS/api/get_credential_creation_options.sql

uniphant--1.2.sql: $(SQL_SRC)
	cat $^ > $@

SQL_SRC = \
  complain_header.sql \
	FUNCTIONS/api/get_credential_creation_options.sql \
  1.1--1.2.sql

uniphant--1.1--1.2.sql: $(SQL_SRC)
	cat $^ > $@
