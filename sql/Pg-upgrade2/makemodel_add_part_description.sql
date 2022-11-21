-- @tag: makemodel_add_part_description
-- @description: Artikelbezeichnung zu jedem Lieferanten speichern können
-- @depends: release_3_7_0

ALTER TABLE makemodel ADD COLUMN part_description TEXT;
