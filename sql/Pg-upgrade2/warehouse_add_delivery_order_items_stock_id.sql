-- @tag: warehouse_add_delivery_order_items_stock_id
-- @description: Constraints für inventory auf delivery_order (dois und do). Ferner sinnvolle Umbenennung zumindestens von einer Spalte (orderitems -> dois)
-- @depends: release_3_1_0
ALTER TABLE inventory RENAME orderitems_id TO delivery_order_items_stock_id;
ALTER TABLE inventory ADD CONSTRAINT delivery_order_items_stock_id_fkey FOREIGN KEY (delivery_order_items_stock_id) REFERENCES delivery_order_items_stock (id);
ALTER TABLE inventory ADD CONSTRAINT oe_id_fkey FOREIGN KEY (oe_id) REFERENCES delivery_orders (id);
