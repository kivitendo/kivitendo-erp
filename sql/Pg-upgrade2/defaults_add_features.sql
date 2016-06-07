-- @tag: defaults_add_features
-- @description: flags to switch on/off the features for the clients
-- @depends: release_3_3_0
ALTER TABLE defaults ADD COLUMN feature_balance BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN feature_datev BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN feature_erfolgsrechnung BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE defaults ADD COLUMN feature_eurechnung BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN feature_ustva BOOLEAN NOT NULL DEFAULT TRUE;
