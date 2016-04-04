-- @tag: defaults_add_country_mode
-- @description: adds new column 'country_mode' (ISO-3166) in table defaults used for erp.ini
-- @depends: release_3_2_0
ALTER TABLE defaults ADD COLUMN country_mode TEXT NOT NULL DEFAULT('DE');

