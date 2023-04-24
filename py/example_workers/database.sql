CREATE USER uniphant WITH SUPERUSER;
CREATE DATABASE uniphant WITH OWNER = uniphant;
\c uniphant
CREATE EXTENSION IF NOT EXISTS uniphant CASCADE;
BEGIN;
\ir database/public.sql
\ir database/opentdb.sql
\ir database/wikipedia.sql
COMMIT;
