-- @tag: defaults_add_precision
-- @description: adds new column 'precision' in table defaults, used to round amounts
-- @depends: release_3_0_0
ALTER TABLE defaults ADD COLUMN precision NUMERIC(15,5) NOT NULL DEFAULT(0.01);

