-- @tag: custom_variables_indices_2
-- @description: Indices für benutzerdefinierte Variablen
-- @depends: release_2_6_2

CREATE INDEX custom_variables_trans_config_module_idx ON custom_variables (config_id, trans_id, sub_module);

