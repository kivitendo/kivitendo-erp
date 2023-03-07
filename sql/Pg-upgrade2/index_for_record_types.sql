-- @tag: index_for_record_types
-- @description: Indexe für Belegtypen erstelllen
-- @depends: deliveryorder_type_to_record_type reclamation_type order_type

CREATE INDEX oe_record_type_key
  ON oe (record_type);

CREATE INDEX reclamations_record_type_key
  ON reclamations (record_type);

CREATE INDEX delivery_orders_record_type_key
  ON delivery_orders (record_type);
