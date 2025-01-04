-- @tag: defaults_add_discount_part
-- @description: Mandantenkonfiguration für Rabattartikel
-- @depends: release_3_9_0

ALTER TABLE defaults ADD COLUMN discount_part_id INTEGER references parts(id);
