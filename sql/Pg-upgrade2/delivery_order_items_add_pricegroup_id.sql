-- @tag: delivery_order_items_add_pricegroup_id
-- @description: Spalten für Preisgruppen-Id für Lieferscheine
-- @depends: release_2_6_3
ALTER TABLE delivery_order_items ADD COLUMN pricegroup_id integer;
