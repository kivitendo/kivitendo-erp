-- @tag: defaults_gln
-- @description: GS1 GLN in der Mandantenkonfiguration
-- @depends: release_3_9_2

ALTER TABLE defaults ADD COLUMN gln text;
