-- @tag: defaults_partsgroup_required
-- @description: New setting to check that partsgroup is set when saving parts
-- @depends: release_3_5_8

ALTER TABLE defaults ADD COLUMN partsgroup_required boolean NOT NULL DEFAULT false;
