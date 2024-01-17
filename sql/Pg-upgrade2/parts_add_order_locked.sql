-- @tag: parts_add_order_locked
-- @description: Spalte für auslaufenden Artikel (nicht mehr bestellbar)
-- @depends: release_3_8_0

ALTER TABLE parts ADD order_locked boolean DEFAULT false;
