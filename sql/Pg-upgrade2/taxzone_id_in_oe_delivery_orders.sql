-- @tag: taxzone_id_in_oe_delivery_orders
-- @description: Werte für Inland in Spalte taxzone_id in Tabellen oe und delivery_orders in Foreign Key zu tax_zones konvertieren; NULL-Werte in ap/ar verhindern; Spalten NOT NULL setzen
-- @depends: change_taxzone_id_0 remove_obsolete_trigger

UPDATE oe              SET taxzone_id = (SELECT id FROM tax_zones WHERE description = 'Inland') WHERE (taxzone_id = 0) OR (taxzone_id IS NULL);
UPDATE delivery_orders SET taxzone_id = (SELECT id FROM tax_zones WHERE description = 'Inland') WHERE (taxzone_id = 0) OR (taxzone_id IS NULL);
UPDATE ar              SET taxzone_id = (SELECT id FROM tax_zones WHERE description = 'Inland') WHERE (taxzone_id = 0) OR (taxzone_id IS NULL);
UPDATE ap              SET taxzone_id = (SELECT id FROM tax_zones WHERE description = 'Inland') WHERE (taxzone_id = 0) OR (taxzone_id IS NULL);

ALTER TABLE oe              ALTER COLUMN taxzone_id SET NOT NULL;
ALTER TABLE delivery_orders ALTER COLUMN taxzone_id SET NOT NULL;
ALTER TABLE ar              ALTER COLUMN taxzone_id SET NOT NULL;
ALTER TABLE ap              ALTER COLUMN taxzone_id SET NOT NULL;

ALTER TABLE oe              ADD CONSTRAINT oe_taxzone_id_fkey              FOREIGN KEY (taxzone_id) REFERENCES tax_zones (id);
ALTER TABLE delivery_orders ADD CONSTRAINT delivery_orders_taxzone_id_fkey FOREIGN KEY (taxzone_id) REFERENCES tax_zones (id);
