-- @tag: remove_redundant_cvar_delete_triggers
-- @description: Entfernt doppelte Trigger zum Löschen von benutzerdefinierten Variablen
-- @depends: custom_variables_delete_via_trigger custom_variables_delete_via_trigger_2 delete_cvars_on_trans_deletion

-- drop triggers
DROP TRIGGER IF EXISTS delete_orderitems_dependencies           ON orderitems;
DROP TRIGGER IF EXISTS delete_delivery_order_items_dependencies ON delivery_order_items;
DROP TRIGGER IF EXISTS delete_invoice_dependencies              ON invoice;
DROP TRIGGER IF EXISTS delete_cv_custom_variables               ON customer;
DROP TRIGGER IF EXISTS delete_cv_custom_variables               ON vendor;
DROP TRIGGER IF EXISTS delete_contact_custom_variables          ON contacts;
DROP TRIGGER IF EXISTS delete_part_custom_variables             ON parts;
DROP TRIGGER IF EXISTS delete_project_custom_variables          ON project;

-- drop functions
DROP FUNCTION IF EXISTS orderitems_before_delete_trigger();
DROP FUNCTION IF EXISTS delivery_order_items_before_delete_trigger();
DROP FUNCTION IF EXISTS invoice_before_delete_trigger();
DROP FUNCTION IF EXISTS delete_cv_custom_variables_trigger();
DROP FUNCTION IF EXISTS delete_contact_custom_variables_trigger();
DROP FUNCTION IF EXISTS delete_part_custom_variables_trigger();
DROP FUNCTION IF EXISTS delete_project_custom_variables_trigger();
