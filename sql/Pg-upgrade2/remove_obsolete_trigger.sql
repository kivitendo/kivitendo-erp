-- @tag: remove_obsolete_trigger
-- @description: Entfernt veraltete Trigger check_inventory
-- @depends: release_3_2_0
-- @encoding: utf-8

-- drop triggers
DROP TRIGGER IF EXISTS check_inventory           ON oe;

-- drop functions
DROP FUNCTION IF EXISTS check_inventory();
