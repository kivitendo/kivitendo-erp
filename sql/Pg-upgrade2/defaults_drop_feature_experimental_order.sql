-- @tag: defaults_drop_feature_experimental_order
-- @description: vormals experimentelles Feature Order ist jetzt der Standard
-- @depends: release_3_9_1

ALTER TABLE defaults DROP COLUMN feature_experimental_order;

