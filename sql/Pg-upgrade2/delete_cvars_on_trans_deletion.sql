-- @tag: delete_cvars_on_trans_deletion
-- @description: Einträge in benutzerdefinierten Variablen löschen, deren Bezugsbelege gelöscht wurde
-- @depends: release_3_1_0

-- 1. Alle benutzerdefinierten Variablen löschen, für die es keine
-- Einträge in den dazugehörigen Tabellen mehr gibt.

-- 1.1. Alle CVars für Artikel selber (sub_module ist leer):
DELETE FROM custom_variables
WHERE (config_id IN (SELECT id FROM custom_variable_configs WHERE module = 'IC'))
  AND (COALESCE(sub_module, '') = '')
  AND (trans_id NOT IN (SELECT id FROM parts));

-- 1.2. Alle CVars für Angebote/Aufträge, Lieferscheine, Rechnungen
-- (sub_module gesetzt):
DELETE FROM custom_variables
WHERE (config_id IN (SELECT id FROM custom_variable_configs WHERE module = 'IC'))
  AND (sub_module = 'orderitems')
  AND (trans_id NOT IN (SELECT id FROM orderitems));

DELETE FROM custom_variables
WHERE (config_id IN (SELECT id FROM custom_variable_configs WHERE module = 'IC'))
  AND (sub_module = 'delivery_order_items')
  AND (trans_id NOT IN (SELECT id FROM delivery_order_items));

DELETE FROM custom_variables
WHERE (config_id IN (SELECT id FROM custom_variable_configs WHERE module = 'IC'))
  AND (sub_module = 'invoice')
  AND (trans_id NOT IN (SELECT id FROM invoice));

-- 1.3. Alle CVars für Kunden/Lieferanten:
DELETE FROM custom_variables
WHERE (config_id IN (SELECT id FROM custom_variable_configs WHERE module = 'CT'))
  AND (trans_id NOT IN (SELECT id FROM customer UNION SELECT id FROM vendor));

-- 1.4. Alle CVars für Ansprechpersonen:
DELETE FROM custom_variables
WHERE (config_id IN (SELECT id FROM custom_variable_configs WHERE module = 'Contacts'))
  AND (trans_id NOT IN (SELECT cp_id FROM contacts));

-- 1.5. Alle CVars für Projekte:
DELETE FROM custom_variables
WHERE (config_id IN (SELECT id FROM custom_variable_configs WHERE module = 'Projects'))
  AND (trans_id NOT IN (SELECT id FROM project));

-- 2. Triggerfunktionen erstellen, die die benutzerdefinierten
-- Variablen löschen.

-- 2.1. Parametrisierte Backend-Funktion zum Löschen:
CREATE OR REPLACE FUNCTION delete_custom_variables_with_sub_module(config_module TEXT, cvar_sub_module TEXT, old_id INTEGER)
RETURNS BOOLEAN AS $$
  BEGIN
    DELETE FROM custom_variables
    WHERE (config_id IN (SELECT id FROM custom_variable_configs WHERE module = config_module))
      AND (COALESCE(sub_module, '') = cvar_sub_module)
      AND (trans_id                 = old_id);

    RETURN TRUE;
  END;
$$ LANGUAGE plpgsql;

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
      PERFORM delete_custom_variables_with_sub_module('Contacts', '', old.id);
    END IF;

    IF (TG_TABLE_NAME = 'project') THEN
      PERFORM delete_custom_variables_with_sub_module('Projects', '', old.id);
    END IF;

    RETURN old;
  END;
$$ LANGUAGE plpgsql;

-- 3. Die eigentlichen Trigger erstellen:

-- 3.1. orderitems
DROP TRIGGER IF EXISTS orderitems_delete_custom_variables_after_deletion ON orderitems;

CREATE TRIGGER orderitems_delete_custom_variables_after_deletion
AFTER DELETE ON orderitems
FOR EACH ROW EXECUTE PROCEDURE delete_custom_variables_trigger();

-- 3.2. delivery_order_items
DROP TRIGGER IF EXISTS delivery_order_items_delete_custom_variables_after_deletion ON delivery_order_items;

CREATE TRIGGER delivery_order_items_delete_custom_variables_after_deletion
AFTER DELETE ON delivery_order_items
FOR EACH ROW EXECUTE PROCEDURE delete_custom_variables_trigger();

-- 3.3. invoice
DROP TRIGGER IF EXISTS invoice_delete_custom_variables_after_deletion ON invoice;

CREATE TRIGGER invoice_delete_custom_variables_after_deletion
AFTER DELETE ON invoice
FOR EACH ROW EXECUTE PROCEDURE delete_custom_variables_trigger();

-- 3.4. parts
DROP TRIGGER IF EXISTS parts_delete_custom_variables_after_deletion ON parts;

CREATE TRIGGER parts_delete_custom_variables_after_deletion
AFTER DELETE ON parts
FOR EACH ROW EXECUTE PROCEDURE delete_custom_variables_trigger();

-- 3.5. customer
DROP TRIGGER IF EXISTS customer_delete_custom_variables_after_deletion ON customer;

CREATE TRIGGER customer_delete_custom_variables_after_deletion
AFTER DELETE ON customer
FOR EACH ROW EXECUTE PROCEDURE delete_custom_variables_trigger();

-- 3.6. vendor
DROP TRIGGER IF EXISTS vendor_delete_custom_variables_after_deletion ON vendor;

CREATE TRIGGER vendor_delete_custom_variables_after_deletion
AFTER DELETE ON vendor
FOR EACH ROW EXECUTE PROCEDURE delete_custom_variables_trigger();

-- 3.7. contacts
DROP TRIGGER IF EXISTS contacts_delete_custom_variables_after_deletion ON contacts;

CREATE TRIGGER contacts_delete_custom_variables_after_deletion
AFTER DELETE ON contacts
FOR EACH ROW EXECUTE PROCEDURE delete_custom_variables_trigger();

-- 3.8. project
DROP TRIGGER IF EXISTS project_delete_custom_variables_after_deletion ON project;

CREATE TRIGGER project_delete_custom_variables_after_deletion
AFTER DELETE ON project
FOR EACH ROW EXECUTE PROCEDURE delete_custom_variables_trigger();
