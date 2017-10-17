-- @tag: defaults_add_feature_production
-- @description: flag to switch on/off the production menu
-- @depends: release_3_5_0
ALTER TABLE defaults ADD COLUMN feature_production BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE defaults ADD COLUMN batchnumber TEXT;
ALTER TABLE defaults ADD COLUMN serialnumber TEXT;

