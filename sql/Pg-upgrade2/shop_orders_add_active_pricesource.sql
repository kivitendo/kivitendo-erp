-- @tag: shop_orders_add_active_price_source
-- @description: Erstellen der Tabellen shop_orders und shop_order_items
-- @depends: release_3_5_0 shop_orders

ALTER TABLE shop_order_items ADD COLUMN active_price_source TEXT;
