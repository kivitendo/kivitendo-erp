-- @tag: makemodel_add_longdescription
-- @description: lange Artikelbezeichnung zu jedem Lieferanten speichern können
-- @depends: release_3_8_0

ALTER TABLE makemodel ADD COLUMN part_longdescription TEXT;
