-- @tag: defaults_add_ean_number
-- @description: EAN-Nummernkreis
-- @depends: release_4_1_0

ALTER TABLE defaults ADD COLUMN part_ean_number text;
