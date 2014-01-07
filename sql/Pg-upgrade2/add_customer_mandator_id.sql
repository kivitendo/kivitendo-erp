-- @tag: add_customer_mandator_id
-- @description: Einführen einer Mandanten ID Spalte bei Kunden und Lieferanten.
-- @depends: release_3_0_0

ALTER TABLE customer ADD mandator_id text;
ALTER TABLE vendor   ADD mandator_id text;
