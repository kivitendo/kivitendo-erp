-- @tag: shop_orders_update_3
-- @description: Ändern der Tabellen shop_orders und shop_order_items. Trigger für oe
-- @depends: shop_orders_update_1 shop_orders_update_2
-- @ignore: 0

ALTER TABLE shop_orders DROP COLUMN oe_trans_id;

DROP FUNCTION update_shop_orders_on_delete_oe() CASCADE;
