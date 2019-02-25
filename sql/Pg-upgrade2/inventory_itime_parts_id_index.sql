-- @tag: inventory_itime_parts_id_index
-- @description: Index auf inventory itime und parts_id, um schnell die letzten Transaktion raussuchen zu können
-- @depends: release_3_5_4

-- increase speed of queries such as

-- last 10 entries in inventory:
-- SELECT * FROM inventory ORDER BY itime desc LIMIT 10

-- last 10 inventory entries for a certain part:
-- SELECT * FROM inventory WHERE parts_id = 1234 ORDER BY itime desc LIMIT 10

CREATE INDEX inventory_itime_parts_id_idx ON inventory (itime, parts_id);
