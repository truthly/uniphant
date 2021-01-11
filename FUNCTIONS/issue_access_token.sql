CREATE OR REPLACE FUNCTION issue_access_token()
RETURNS boolean
LANGUAGE sql
AS $$
WITH
new AS (
  INSERT INTO access_tokens (user_id, expire_at)
  SELECT user_id(), now() + settings.verify_assertion_access_token_cookie_max_age
  FROM settings
  RETURNING access_tokens.access_token, access_tokens.expire_at
)
SELECT set_config('response.headers', format(
  '[{"Set-Cookie": "access_token=%s; path=/; HttpOnly; SameSite=Strict%s%s"}]',
  new.access_token,
  CASE WHEN effective_domain() = 'localhost' THEN '' ELSE '; Secure' END,
  '; Expires=' || to_char(new.expire_at AT TIME ZONE 'GMT','Dy, DD Mon YYYY HH:MI:SS GMT')
), TRUE) IS NOT NULL
FROM new
$$;
