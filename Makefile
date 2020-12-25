EXTENSION = uniphant
DATA = uniphant--1.0.sql
REGRESS = test
EXTRA_CLEAN = uniphant--1.0.sql

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

all: uniphant--1.0.sql

SQL_SRC = \
  complain_header.sql \
  FUNCTIONS/effective_domain.sql \
  FUNCTIONS/remote_ip.sql \
  TABLES/users.sql \
	TABLES/tokens.sql \
  FUNCTIONS/api/init_credential.sql \
  FUNCTIONS/api/make_credential.sql \
  FUNCTIONS/api/get_credentials.sql \
  FUNCTIONS/api/verify_assertion.sql \
	FUNCTIONS/api/is_signed_in.sql \
	FUNCTIONS/api/sign_out.sql

uniphant--1.0.sql: $(SQL_SRC)
	cat $^ > $@
