-- @tag: custom_variables_delete_via_trigger_requirement_specs
-- @description: Benutzerdefinierte Variablen von Pflichtenheften via Trigger löschen
-- @depends: custom_variables_delete_via_trigger requirement_specs
CREATE OR REPLACE FUNCTION delete_requirement_spec_custom_variables_trigger() RETURNS trigger AS $$
  BEGIN
    DELETE FROM custom_variables WHERE (sub_module = '' OR sub_module IS NULL)
                                   AND trans_id = OLD.id
                                   AND (SELECT module FROM custom_variable_configs WHERE id = config_id) = 'RequirementSpecs';

    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS delete_requirement_spec_custom_variables ON requirement_specs;

CREATE TRIGGER delete_requirement_spec_custom_variables
BEFORE DELETE ON requirement_specs
FOR EACH ROW EXECUTE PROCEDURE delete_requirement_spec_custom_variables_trigger();
