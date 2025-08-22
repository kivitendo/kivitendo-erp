-- @tag: defaults_add_feature_experimental_invoice
-- @description: Feature für experimentellen Invoice Controller
-- @depends: release_3_9_2

ALTER TABLE defaults ADD COLUMN feature_experimental_invoice BOOLEAN NOT NULL DEFAULT FALSE;
