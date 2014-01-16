-- @tag: delete_close_follow_ups_when_order_is_deleted_closed
-- @description: Wiedervorlagen löschen/schließen, wenn dazugehörige Belege gelöscht/geschlossen werden
-- @depends: delete_close_follow_ups_when_order_is_deleted_closed_fkey_deletion

ALTER TABLE follow_up_links ADD CONSTRAINT follow_up_links_follow_up_id_fkey FOREIGN KEY (follow_up_id) REFERENCES follow_ups (id) ON DELETE CASCADE;

CREATE OR REPLACE FUNCTION follow_up_delete_notes_trigger()
RETURNS TRIGGER AS $$
  BEGIN
    DELETE FROM notes
    WHERE (trans_id     = OLD.id)
      AND (trans_module = 'fu');
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION follow_up_delete_when_oe_is_deleted_trigger()
RETURNS TRIGGER AS $$
  BEGIN
    DELETE FROM follow_ups
    WHERE id IN (
      SELECT follow_up_id
      FROM follow_up_links
      WHERE (trans_id   = OLD.id)
        AND (trans_type IN ('sales_quotation',   'sales_order',    'sales_delivery_order',    'sales_invoice',
                            'request_quotation', 'purchase_order', 'purchase_delivery_order', 'purchase_invoice'))
    );

    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION follow_up_delete_when_customer_vendor_is_deleted_trigger()
RETURNS TRIGGER AS $$
  BEGIN
    DELETE FROM follow_ups
    WHERE id IN (
      SELECT follow_up_id
      FROM follow_up_links
      WHERE (trans_id   = OLD.id)
        AND (trans_type IN ('customer', 'vendor'))
    );

    DELETE FROM notes
    WHERE (trans_id     = OLD.id)
      AND (trans_module = 'ct');

    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

-- ============================================================

DROP TRIGGER IF EXISTS follow_up_delete_notes ON follow_ups;

CREATE TRIGGER follow_up_delete_notes
AFTER DELETE ON follow_ups
FOR EACH ROW  EXECUTE PROCEDURE follow_up_delete_notes_trigger();

DROP TRIGGER IF EXISTS oe_before_delete_clear_follow_ups ON oe;

CREATE TRIGGER oe_before_delete_clear_follow_ups
BEFORE DELETE ON oe
FOR EACH ROW  EXECUTE PROCEDURE follow_up_delete_when_oe_is_deleted_trigger();

DROP TRIGGER IF EXISTS customer_before_delete_clear_follow_ups ON customer;
DROP TRIGGER IF EXISTS vendor_before_delete_clear_follow_ups   ON vendor;

CREATE TRIGGER customer_before_delete_clear_follow_ups
AFTER DELETE ON customer
FOR EACH ROW  EXECUTE PROCEDURE follow_up_delete_when_customer_vendor_is_deleted_trigger();

CREATE TRIGGER vendor_before_delete_clear_follow_ups
AFTER DELETE ON vendor
FOR EACH ROW  EXECUTE PROCEDURE follow_up_delete_when_customer_vendor_is_deleted_trigger();

-- ============================================================

CREATE OR REPLACE FUNCTION follow_up_close_when_oe_closed_trigger()
RETURNS TRIGGER AS $$
  BEGIN
    IF COALESCE(NEW.closed, FALSE) AND NOT COALESCE(OLD.closed, FALSE) THEN
      UPDATE follow_ups
      SET done = TRUE
      WHERE id IN (
        SELECT follow_up_id
        FROM follow_up_links
        WHERE (trans_id   = NEW.id)
          AND (trans_type IN ('sales_quotation',   'sales_order',    'sales_delivery_order',
                              'request_quotation', 'purchase_order', 'purchase_delivery_order'))
      );
    END IF;

    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS oe_on_update_close_follow_up ON oe;

CREATE TRIGGER  oe_on_update_close_follow_up
AFTER UPDATE ON oe
FOR EACH ROW  EXECUTE PROCEDURE follow_up_close_when_oe_closed_trigger();

DROP TRIGGER IF EXISTS delivery_orders_on_update_close_follow_up ON delivery_orders;

CREATE TRIGGER  delivery_orders_on_update_close_follow_up
AFTER UPDATE ON delivery_orders
FOR EACH ROW  EXECUTE PROCEDURE follow_up_close_when_oe_closed_trigger();
