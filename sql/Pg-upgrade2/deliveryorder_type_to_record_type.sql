-- @tag: deliveryorder_type_to_record_type
-- @description: Convert deliveryorder_type to record_type enum
-- @depends: deliveryorder_type

CREATE TYPE delivery_order_types AS ENUM (
  'sales_delivery_order',
  'purchase_delivery_order',
  'supplier_delivery_order',
  'rma_delivery_order'
);

ALTER TABLE delivery_orders ADD COLUMN record_type delivery_order_types;

UPDATE delivery_orders SET record_type = 'sales_delivery_order'
  WHERE order_type = 'sales_delivery_order';
UPDATE delivery_orders SET record_type = 'purchase_delivery_order'
  WHERE order_type = 'purchase_delivery_order';
UPDATE delivery_orders SET record_type = 'supplier_delivery_order'
  WHERE order_type = 'supplier_delivery_order';
UPDATE delivery_orders SET record_type = 'rma_delivery_order'
  WHERE order_type = 'rma_delivery_order';

ALTER TABLE delivery_orders ALTER COLUMN record_type SET NOT NULL;
ALTER TABLE delivery_orders DROP COLUMN order_type;
