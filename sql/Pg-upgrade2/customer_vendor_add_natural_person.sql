-- @tag: customer_vendor_add_natural_person
-- @description: neue Spalte für "natürliche Person" bei Kunden/Lieferanten
-- @depends: release_3_5_5

ALTER TABLE customer ADD COLUMN natural_person BOOLEAN DEFAULT FALSE;
ALTER TABLE vendor   ADD COLUMN natural_person BOOLEAN DEFAULT FALSE;
