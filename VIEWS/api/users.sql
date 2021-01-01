CREATE OR REPLACE VIEW api.users AS
SELECT
user_id,
username,
parent_user_id
FROM users;
