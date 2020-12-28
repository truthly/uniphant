CREATE OR REPLACE FUNCTION user_id()
RETURNS bigint
STABLE
LANGUAGE sql
AS $$
SELECT access_tokens.user_id
FROM access_tokens
WHERE access_tokens.access_token = NULLIF(current_setting('request.cookie.access_token', TRUE),'')::uuid
AND (access_tokens.expire_at > now()) IS NOT FALSE;
$$;
