-- @tag: defaults_oe_subversion
-- @description: Konfigurations-Option, ob Unterversionen gesperrt werden
-- @depends: release_3_6_1

ALTER TABLE defaults ADD COLUMN lock_oe_subversions BOOLEAN NOT NULL DEFAULT FALSE;
