-- @tag: files_add_variant
-- @description: Varianten für DMS System
-- @depends: release_3_5_8

ALTER TABLE files ADD COLUMN print_variant text;
