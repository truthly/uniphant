CREATE OR REPLACE VIEW api.user_credentials WITH (security_barrier) AS
SELECT
credential_id,
device_name,
valid
FROM credentials
WHERE user_id = user_id();
