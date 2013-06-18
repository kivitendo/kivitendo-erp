-- @tag: warehouse_add_bestbefore
-- @description: Spalten für Mindesthaltbarkeitsdatum
-- @depends: release_2_6_0
ALTER TABLE inventory ADD COLUMN bestbefore date;
ALTER TABLE delivery_order_items_stock ADD COLUMN bestbefore date;
