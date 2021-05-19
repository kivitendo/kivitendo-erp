-- @tag: customer_vendor_add_postal_invoice
-- @description: neue Spalte für "Rechnungsempfang nur per Post" bei Kunden
-- @depends: release_3_5_6_1

ALTER TABLE customer ADD COLUMN postal_invoice BOOLEAN DEFAULT FALSE;
