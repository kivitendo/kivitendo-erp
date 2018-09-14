-- @tag: customer_add_fields
-- @description: Rechnungsadresse (E-Mail-Empfänger) Herkunft der personenbezogenen Daten
-- @depends: release_3_5_3
ALTER TABLE customer ADD COLUMN invoice_mail text;
ALTER TABLE customer ADD COLUMN contact_origin text;
