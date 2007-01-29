-- @tag: parts_ean
-- @description: Neues Feld f&uuml;r EAN-Code
-- @depends: release_2_4_1
ALTER TABLE parts ADD COLUMN ean text;
