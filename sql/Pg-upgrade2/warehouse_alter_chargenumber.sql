-- @tag: warehouse_alter_chargenumber
-- @description: Chargennummber von NULL auf '' aktualisieren
-- @depends: release_2_6_3
UPDATE inventory set chargenumber='' where chargenumber IS NULL;
ALTER TABLE inventory ALTER COLUMN chargenumber SET NOT NULL;
ALTER TABLE inventory ALTER COLUMN chargenumber SET  default '';

