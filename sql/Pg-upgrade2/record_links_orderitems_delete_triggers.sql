-- @tag: record_links_orderitems_delete_triggers
-- @description: delete trigger für verknüpfte invoice(items), orderitems und delivery_order_items
-- @depends: record_links_post_delete_triggers2 release_3_1_0
CREATE OR REPLACE FUNCTION clean_up_record_links_before_orderitems_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM record_links
      WHERE (from_table = 'orderitems' AND from_id = OLD.id)
         OR (to_table   = 'orderitems' AND to_id   = OLD.id);
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION clean_up_record_links_before_delivery_order_items_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM record_links
      WHERE (from_table = 'delivery_order_items' AND from_id = OLD.id)
         OR (to_table   = 'delivery_order_items' AND to_id   = OLD.id);
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION clean_up_record_links_before_invoice_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM record_links
      WHERE (from_table = 'invoice' AND from_id = OLD.id)
         OR (to_table   = 'invoice' AND to_id   = OLD.id);
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;



CREATE TRIGGER before_delete_orderitems_trigger
BEFORE DELETE ON orderitems FOR EACH ROW EXECUTE
PROCEDURE clean_up_record_links_before_orderitems_delete();

CREATE TRIGGER before_delete_delivery_order_items_trigger
BEFORE DELETE ON delivery_order_items FOR EACH ROW EXECUTE
PROCEDURE clean_up_record_links_before_delivery_order_items_delete();

CREATE TRIGGER before_delete_invoice_trigger
BEFORE DELETE ON invoice FOR EACH ROW EXECUTE
PROCEDURE clean_up_record_links_before_invoice_delete();



