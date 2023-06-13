-- @tag: defaults_webdav
-- @description: Synchronisation mit externem WebDAV-Server
-- @depends: release_3_8_0
ALTER TABLE defaults ADD COLUMN webdav_sync_extern boolean DEFAULT false;
ALTER TABLE defaults ADD COLUMN webdav_sync_extern_url text;
ALTER TABLE defaults ADD COLUMN webdav_sync_extern_login text;
ALTER TABLE defaults ADD COLUMN webdav_sync_extern_pass text;
