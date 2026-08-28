-- @tag: defaults_endtoend_enabled_by_default
-- @description: Standardmäßig wird die END-TO-END Id zur Duplikaterkennung für den Bankimport verwendet
-- @depends: release_4_1_0

UPDATE defaults SET check_bt_duplicates_endtoend = true;
