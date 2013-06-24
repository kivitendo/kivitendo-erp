-- @tag: drop_dpt_trans
-- @description: Löscht nicht mehr benötigte Tabelle dpt_trans
-- @depends: release_3_0_0

-- Drop table dpt_trans:
DROP TABLE dpt_trans;

-- Drop all Trigger which manage dpt_trans:
DROP TRIGGER check_department ON ar;
DROP TRIGGER check_department ON ap;
DROP TRIGGER check_department ON gl;
DROP TRIGGER check_department ON oe;
DROP TRIGGER del_department ON ar;
DROP TRIGGER del_department ON ap;
DROP TRIGGER del_department ON gl;
DROP TRIGGER del_department ON oe;

-- Drop all functions where dpt_trans is used:
DROP FUNCTION check_department();
DROP FUNCTION del_department();
