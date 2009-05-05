-- @tag: warehouse2
-- @description: Defaultwert für onhand
-- @depends: warehouse
UPDATE parts SET onhand = COALESCE((SELECT SUM(qty) FROM inventory WHERE inventory.parts_id = parts.id), 0);
ALTER TABLE parts ALTER COLUMN onhand SET DEFAULT 0;
