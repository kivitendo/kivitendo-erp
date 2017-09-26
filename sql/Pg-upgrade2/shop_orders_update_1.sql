-- @tag: shop_orders_update_1
-- @description: Ändern der Tabellen shop_orders und shop_order_items. Trigger für oe
-- @depends: release_3_5_0 shop_orders shop_orders_add_active_price_source
-- @ignore: 0

ALTER TABLE shop_orders ADD FOREIGN KEY (shop_id) REFERENCES shops(id);
ALTER TABLE shop_orders ADD FOREIGN KEY (kivi_customer_id) REFERENCES customer(id);
ALTER TABLE shop_orders DROP COLUMN shop_data;
ALTER TABLE shop_order_items DROP COLUMN shop_id;

CREATE OR REPLACE FUNCTION update_shop_orders_on_delete_oe() RETURNS TRIGGER AS $$
  BEGIN
    UPDATE shop_orders SET oe_trans_id = NULL WHERE oe_trans_id = OLD.id;

    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_delete_oe_trigger
AFTER DELETE ON oe FOR EACH ROW EXECUTE
PROCEDURE update_shop_orders_on_delete_oe();
