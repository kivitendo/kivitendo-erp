-- @tag: customer_vendor_shipto_add_gln
-- @description: Spalte für GLN bei Kunde/Lieferant und Lieferadresse
-- @depends: release_3_3_0

ALTER TABLE customer ADD COLUMN       gln TEXT;
ALTER TABLE vendor   ADD COLUMN       gln TEXT;
ALTER TABLE shipto   ADD COLUMN shiptogln TEXT;
