-- @tag: custom_variables_validity_index
-- @description: Indizes für Tabelle custom_variables_validity
-- @depends: release_3_0_0
CREATE INDEX idx_custom_variables_validity_config_id_trans_id
ON custom_variables_validity (config_id, trans_id);

CREATE INDEX idx_custom_variables_validity_trans_id
ON custom_variables_validity (trans_id);
