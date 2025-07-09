-- @tag: defaults_endtoend
-- @description: Einstellung, ob die END-TO-END Id zur Duplikaterkennung für den Bankimport verwendet werden darf
-- @depends: release_3_9_0

ALTER TABLE defaults ADD COLUMN check_bt_duplicates_endtoend boolean DEFAULT FALSE;
