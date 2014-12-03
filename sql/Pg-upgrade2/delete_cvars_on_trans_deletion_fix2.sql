-- @tag: delete_cvars_on_trans_deletion_fix2
-- @description: Bugfix 2 für das Löschen von benutzerdefinierten Variablen via Triggerfunktionen
-- @depends: delete_cvars_on_trans_deletion_fix1

-- 2.1. Parametrisierte Backend-Funktion zum Löschen:
CREATE OR REPLACE FUNCTION delete_custom_variables_with_sub_module(config_module TEXT, cvar_sub_module TEXT, old_id INTEGER)
RETURNS BOOLEAN AS $$
  BEGIN
    DELETE FROM custom_variables
    WHERE EXISTS (SELECT id FROM custom_variable_configs cfg WHERE (cfg.module = config_module) AND (custom_variables.config_id = cfg.id))
      AND (COALESCE(sub_module, '') = cvar_sub_module)
      AND (trans_id                 = old_id);

    RETURN TRUE;
  END;
$$ LANGUAGE plpgsql;
