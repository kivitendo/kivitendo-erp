-- @tag: language_obsolete
-- @description: Sprachen ungültig setzen
-- @depends: release_3_6_0
-- @ignore: 0

ALTER TABLE language ADD COLUMN obsolete BOOLEAN DEFAULT FALSE;
