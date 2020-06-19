-- @tag: gl_add_deliverydate
-- @description: Liefer-/Leistungsdatum in Dialogbuchungen
-- @depends: release_3_5_5

ALTER TABLE gl ADD COLUMN deliverydate DATE;
