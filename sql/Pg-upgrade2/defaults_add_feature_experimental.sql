-- @tag: defaults_add_feature_experimental
-- @description: Konfigurations-Option, ob experimentelle Features verwendet werden sollen.
-- @depends: release_3_4_1

ALTER TABLE defaults ADD COLUMN feature_experimental BOOLEAN NOT NULL DEFAULT TRUE;
