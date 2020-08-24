-- @tag: delete_cvars_on_trans_deletion_add_shipto
-- @description: Löschen von benutzerdefinierten Variablen via Triggerfunktionen auch für shipto
-- @depends: delete_cvars_on_trans_deletion delete_cvars_on_trans_deletion_fix1

-- 1.6 Alle benutzerdefinierten Variablen löschen, für die es keine
-- Einträge in shipto mehr gibt.
DELETE FROM custom_variables WHERE EXISTS
  (SELECT cv.id FROM custom_variables cv LEFT JOIN custom_variable_configs cvc ON (cv.config_id = cvc.id)
   WHERE module LIKE 'ShipTo'
     AND NOT EXISTS (SELECT shipto_id FROM shipto WHERE shipto_id = cv.trans_id));


-- 2.2. Nun die Funktionen, die als Trigger aufgerufen wird und die
-- entscheidet, wie genau zu löschen ist:
CREATE OR REPLACE FUNCTION delete_custom_variables_trigger()
RETURNS TRIGGER AS $$
  BEGIN
    IF (TG_TABLE_NAME IN ('orderitems', 'delivery_order_items', 'invoice')) THEN
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

-- 3. Die eigentlichen Trigger erstellen:

-- 3.9. shipto
DROP TRIGGER IF EXISTS shipto_delete_custom_variables_after_deletion ON shipto;

CREATE TRIGGER shipto_delete_custom_variables_after_deletion
AFTER DELETE ON shipto
FOR EACH ROW EXECUTE PROCEDURE delete_custom_variables_trigger();
