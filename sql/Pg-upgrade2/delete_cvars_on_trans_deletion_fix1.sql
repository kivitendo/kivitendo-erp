-- @tag: delete_cvars_on_trans_deletion_fix1
-- @description: Bugfix 1 für das Löschen von benutzerdefinierten Variablen via Triggerfunktionen
-- @depends: delete_cvars_on_trans_deletion

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

    RETURN old;
  END;
$$ LANGUAGE plpgsql;
