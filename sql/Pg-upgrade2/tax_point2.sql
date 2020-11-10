-- @tag: tax_point2
-- @description: Feld Leistungsdatum in Lieferscheinen
-- @depends: tax_point
ALTER TABLE delivery_orders ADD COLUMN tax_point DATE;
