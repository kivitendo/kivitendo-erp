-- @tag: custom_variables_indices
-- @description: Indices für benutzerdefinierte Variablen
-- @depends: release_2_6_2

CREATE INDEX custom_variables_sub_module_idx ON custom_variables (sub_module);
CREATE INDEX custom_variables_config_id_idx ON custom_variables (config_id);

