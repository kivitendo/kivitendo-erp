-- @tag: deliveryorder_type
-- @description: Persistente Typen in Lieferscheinen
-- @depends: release_3_5_8

ALTER TABLE delivery_orders ADD COLUMN order_type TEXT;

UPDATE delivery_orders SET order_type = 'sales_delivery_order' WHERE customer_id IS NOT NULL;
UPDATE delivery_orders SET order_type = 'purchase_delivery_order' WHERE vendor_id IS NOT NULL;

ALTER TABLE delivery_orders ALTER COLUMN order_type SET NOT NULL;


