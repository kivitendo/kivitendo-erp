-- @tag: customer_vendor_taxzone_id
-- @description: Die Spalte &quot;taxzone_id&quot; in den Tabellen customer und vendor darf nicht NULL sein.
-- @depends: release_2_4_1
UPDATE customer SET taxzone_id = 0 WHERE taxzone_id ISNULL;
ALTER TABLE customer ALTER COLUMN taxzone_id SET DEFAULT 0;
ALTER TABLE customer ALTER COLUMN taxzone_id SET NOT NULL;

UPDATE vendor SET taxzone_id = 0 WHERE taxzone_id ISNULL;
ALTER TABLE vendor ALTER COLUMN taxzone_id SET DEFAULT 0;
ALTER TABLE vendor ALTER COLUMN taxzone_id SET NOT NULL;
