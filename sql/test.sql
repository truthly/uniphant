BEGIN;

--
-- This only tests the extension can be installed
-- and calls a few functions that can easily be tested.
--
-- For a more complete integration test,
-- see .github/workflows/build-test.yml
--

CREATE EXTENSION uniphant WITH SCHEMA public CASCADE;

SELECT set_config('request.header.origin','http://localhost',FALSE);
SELECT effective_domain();

SELECT set_config('request.header.origin','http://example.com',FALSE);
SELECT effective_domain();

SELECT set_config('request.header.X-Forwarded-For','127.0.0.1',FALSE);
SELECT remote_ip();

SELECT set_config('request.header.X-Forwarded-For','192.168.123.123',FALSE);
SELECT remote_ip();

SELECT set_config('request.path','/rpc/sign_up',FALSE);
SELECT auth();
SELECT api.sign_up(username := 'test', device_name := 'iPhone') IS NOT NULL;
SELECT user_id, username FROM users;
SELECT user_id FROM access_tokens;

ROLLBACK;
