-- @tag: session_content_auto_restore
-- @description: Spalte "auto_restore" in auth.session_content
-- @depends:
ALTER TABLE auth.session_content ADD COLUMN auto_restore boolean;
UPDATE auth.session_content SET auto_restore = FALSE;
