-- @tag: defaults_fuzzy_skonto
-- @description: Einstellung, ob unscharfes Skonto erlaubt und wen ja mit welcher prozentualen Abweichung
-- @depends: release_3_8_0

ALTER TABLE defaults ADD COLUMN fuzzy_skonto boolean DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN fuzzy_skonto_percentage real DEFAULT 0.5;
