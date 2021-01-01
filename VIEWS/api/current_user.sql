CREATE OR REPLACE VIEW api.current_user WITH (security_barrier) AS
SELECT
user_id,
username
FROM users
WHERE user_id = user_id();
