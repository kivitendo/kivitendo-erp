-- @tag: shop_orders_update_4
-- @description: Ändern der Tabellen shop_orders, shop_trans_id darf auch Text enthalten
-- @depends: shop_orders_update_1 shop_orders_update_2 shop_orders_update_3

-- @ignore: 0

ALTER TABLE shop_orders ALTER COLUMN shop_trans_id TYPE text;
ALTER TABLE shop_order_items ALTER COLUMN shop_trans_id TYPE text;
