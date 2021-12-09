-- @tag: delete_cvars_on_trans_deletion_add_reclamation_items
-- @description: Add reclamation_items to trigger
-- @depends: delete_cvars_on_trans_deletion_add_shipto reclamations

CREATE OR REPLACE FUNCTION delete_custom_variables_trigger()
RETURNS TRIGGER AS $$
  BEGIN
    IF (TG_TABLE_NAME IN ('orderitems', 'delivery_order_items', 'invoice', 'reclamation_items')) THEN
      PERFORM delete_custom_variables_with_sub_module('IC', TG_TABLE_NAME, old.id);
    END IF;

    IF (TG_TABLE_NAME = 'parts') THEN
      PERFORM delete_custom_variables_with_sub_module('IC', '', old.id);
    END IF;

    IF (TG_TABLE_NAME IN ('customer', 'vendor')) THEN
      PERFORM delete_custom_variables_with_sub_module('CT', '', old.id);
    END IF;

    IF (TG_TABLE_NAME = 'contacts') THEN
      PERFORM delete_custom_variables_with_sub_module('Contacts', '', old.cp_id);
    END IF;

    IF (TG_TABLE_NAME = 'project') THEN
      PERFORM delete_custom_variables_with_sub_module('Projects', '', old.id);
    END IF;

    IF (TG_TABLE_NAME = 'shipto') THEN
      PERFORM delete_custom_variables_with_sub_module('ShipTo', '', old.shipto_id);
    END IF;

    RETURN old;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER reclamation_items_delete_custom_variables_after_deletion
AFTER DELETE ON reclamation_items
FOR EACH ROW EXECUTE PROCEDURE delete_custom_variables_trigger();
