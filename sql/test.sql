BEGIN;

--
-- This only tests the extension can be installed
-- and calls a few functions that can easily be tested.
--
-- For a more complete integration test,
-- see .github/workflows/build-test.yml
--

CREATE EXTENSION uniphant CASCADE;

SELECT set_config('request.header.origin','http://localhost',FALSE);
SELECT effective_domain();

SELECT set_config('request.header.origin','http://example.com',FALSE);
SELECT effective_domain();

SELECT set_config('request.header.X-Forwarded-For','127.0.0.1',FALSE);
SELECT remote_ip();

SELECT set_config('request.header.X-Forwarded-For','192.168.123.123',FALSE);
SELECT remote_ip();

SELECT api.sign_up(username := 'test');
SELECT user_id, username FROM users;
SELECT user_id FROM access_tokens;
SELECT api.sign_out();

ROLLBACK;
