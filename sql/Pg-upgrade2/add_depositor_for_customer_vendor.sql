-- @tag: add_depositor_for_customer_vendor
-- @description: Einführen einer Depositor (Kontoinhaber) Spalte bei Customer bzw. Vendor
-- @depends: sepa

ALTER TABLE customer          ADD depositor     text;
ALTER TABLE vendor            ADD depositor     text;
ALTER TABLE sepa_export_items ADD our_depositor text;
ALTER TABLE sepa_export_items ADD vc_depositor  text;

UPDATE customer SET depositor = name;
UPDATE vendor   SET depositor = name;
