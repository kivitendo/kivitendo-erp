-- @tag: add_api_token
-- @description: Feld 'api_token' in 'session' ergänzen
-- @depends:
-- @charset: utf-8
ALTER TABLE auth.session ADD COLUMN api_token text;
