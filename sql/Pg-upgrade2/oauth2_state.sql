-- @tag: oauth2_state
-- @description: OAuth2 store state for authorization code handling
-- @depends: release_3_9_1

ALTER TABLE oauth_token ADD COLUMN tokenstate TEXT;
ALTER TABLE oauth_token ADD COLUMN redirect_uri TEXT;
ALTER TABLE oauth_token alter column access_token drop NOT NULL;
ALTER TABLE oauth_token alter column access_token_expiration drop NOT NULL;
ALTER TABLE oauth_token alter column refresh_token drop NOT NULL;
