BEGIN;

CREATE EXTENSION uniphant CASCADE;

SELECT set_config('request.header.origin','http://localhost',FALSE);
SELECT effective_domain();

SELECT set_config('request.header.origin','http://example.com',FALSE);
SELECT effective_domain();

SELECT set_config('request.header.X-Forwarded-For','127.0.0.1',FALSE);
SELECT remote_ip();

SELECT set_config('request.header.X-Forwarded-For','192.168.123.123',FALSE);
SELECT remote_ip();

ROLLBACK;
