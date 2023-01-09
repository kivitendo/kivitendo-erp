-- @tag: delivery_order_remove_is_sales_in_db
-- @description: Lösche 'is_sales' in delivery_orders Tabelle
-- @depends: release_3_6_1

ALTER TABLE delivery_orders
  DROP COLUMN is_sales;
