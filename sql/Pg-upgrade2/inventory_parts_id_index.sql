-- @tag: inventory_parts_id_index
-- @description: Index auf inventory parts_id, um schneller die Bestände eines Artikels in diversen Lagern zu berechnen
-- @depends: release_3_5_4

-- increase speed of queries for inventory information on one part, e.g.

--   SELECT parts_id, warehouse_id, bin_id, sum(qty)
--     FROM inventory
--    WHERE parts_id = 1234
-- GROUP BY parts_id, bin_id, warehouse_id;

CREATE INDEX inventory_parts_id_idx ON inventory (parts_id);
