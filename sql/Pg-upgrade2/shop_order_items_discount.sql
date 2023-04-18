-- @tag: shop_order_items_discount
-- @description: shop_order_items haben einen identifier und referenzieren prozentualen rabatt
-- @depends: shop_orders_update_4

-- @ignore: 0

ALTER TABLE shop_order_items ADD COLUMN discount      REAL;
ALTER TABLE shop_order_items ADD COLUMN discount_code TEXT;
ALTER TABLE shop_order_items ADD COLUMN identitfier   TEXT;
