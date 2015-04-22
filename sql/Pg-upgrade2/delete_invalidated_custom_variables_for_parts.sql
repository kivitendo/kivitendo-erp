-- @tag: delete_invalidated_custom_variables_for_parts
-- @description: Bei Artikeln ungültig gesetzte, benutzerdefinierte Variablen löschen
-- @depends: release_3_2_0
DELETE FROM custom_variables
WHERE (config_id IN (
    SELECT id
    FROM custom_variable_configs
    WHERE module = 'IC'))
  AND EXISTS (
    SELECT val.id
    FROM custom_variables_validity val
    WHERE (val.config_id = custom_variables.config_id)
      AND (val.trans_id  = custom_variables.trans_id));
