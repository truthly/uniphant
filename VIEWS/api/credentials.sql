CREATE OR REPLACE VIEW api.credentials AS
SELECT
credential_id,
device_name,
user_id,
valid
FROM credentials;
