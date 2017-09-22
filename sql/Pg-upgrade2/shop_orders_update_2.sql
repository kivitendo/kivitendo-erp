-- @tag: shop_orders_update_2
-- @description: Ändern der Tabellen shop_orders für Trigger spalte war falsch benannt
-- @depends: shop_orders_update_1
-- @ignore: 0

ALTER TABLE shop_orders RENAME COLUMN oe_transid TO oe_trans_id;
