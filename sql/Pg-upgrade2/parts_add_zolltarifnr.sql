-- @tag: parts_zolltarifnr
-- @description: Neues Feld für Zolltarifnummer
-- @depends: release_3_8_0
ALTER TABLE parts ADD COLUMN tariff_code text;

