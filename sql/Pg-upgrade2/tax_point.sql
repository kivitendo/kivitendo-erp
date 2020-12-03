-- @tag: tax_point
-- @description: Feld Leistungsdatum in Einkaufs- & Verkaufsbelegen
-- @depends: release_3_5_6_1
ALTER TABLE ap ADD COLUMN tax_point DATE;
ALTER TABLE ar ADD COLUMN tax_point DATE;
ALTER TABLE gl ADD COLUMN tax_point DATE;
ALTER TABLE oe ADD COLUMN tax_point DATE;
