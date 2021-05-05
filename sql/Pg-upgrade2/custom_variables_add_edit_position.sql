-- @tag: custom_variables_add_edit_position
-- @description: Erweiterung custom_variables
-- @depends: release_3_5_6_1 custom_variables

ALTER TABLE custom_variable_configs ADD COLUMN first_tab BOOLEAN NOT NULL DEFAULT FALSE;

