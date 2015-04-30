-- @tag: remove_obsolete_trigger
-- @description: Entfernt veraltete Trigger check_inventory

-- drop triggers
DROP TRIGGER IF EXISTS check_inventory           ON oe;

-- drop functions
DROP FUNCTION IF EXISTS check_inventory();
