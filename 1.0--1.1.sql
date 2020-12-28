ALTER TABLE settings ALTER COLUMN verify_assertion_access_token_cookie_max_age DROP NOT NULL;
ALTER TABLE tokens RENAME TO access_tokens;
ALTER TABLE access_tokens RENAME token TO access_token;
ALTER TABLE access_tokens ALTER COLUMN expire_at DROP NOT NULL;
ALTER INDEX "tokens_pkey" RENAME TO "access_tokens_pkey";
DROP FUNCTION api.verify_assertion(text,credential_type,text,text,text,text);
DROP FUNCTION api.init_credential(text,text);
ALTER TABLE users DROP COLUMN display_name;
