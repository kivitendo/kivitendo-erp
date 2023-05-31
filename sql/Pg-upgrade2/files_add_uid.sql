-- @tag: files_add_uid
-- @description: unique Identifier (UID) für DMS System
-- @depends: release_3_8_0

ALTER TABLE files ADD COLUMN uid text;
