ALTER TABLE credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE credentials FORCE ROW LEVEL SECURITY;

CREATE POLICY credentials_check_user_id_for_insert ON credentials
  FOR INSERT
  TO api
  WITH CHECK (user_id = user_id() OR NOT valid);

CREATE POLICY credentials_check_user_id_for_update ON credentials
  FOR UPDATE
  TO api
  USING (user_id = user_id() OR has_role('admin'))
  WITH CHECK (user_id = user_id() OR has_role('admin'));

CREATE POLICY credentials_check_user_id_for_select_to_webanon ON credentials
  FOR SELECT
  TO web_anon
  USING (user_id = user_id() OR has_role('admin'));

--
-- need to see all rows to verify signature befored signed-in
--
CREATE POLICY credentials_check_user_id_for_select_to_api ON credentials
  FOR SELECT
  TO api
  USING (TRUE);

ALTER TABLE access_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_tokens FORCE ROW LEVEL SECURITY;

CREATE POLICY access_tokens_select ON access_tokens
  FOR SELECT
  TO api
  USING (
    user_id = user_id()
    OR
    (
      access_token = NULLIF(current_setting('request.cookie.access_token', TRUE),'')::uuid
      AND (expire_at > now()) IS NOT FALSE
    )
  );

CREATE POLICY access_tokens_issue_insert ON access_tokens
  FOR INSERT
  TO api
  WITH CHECK (user_id = user_id());

CREATE POLICY access_tokens_revoke ON access_tokens
  FOR DELETE
  TO api
  USING (access_token = NULLIF(current_setting('request.cookie.access_token', TRUE),'')::uuid);
