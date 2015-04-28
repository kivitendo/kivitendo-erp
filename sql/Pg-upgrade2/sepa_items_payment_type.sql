-- @tag: sepa_items_payment_type
-- @description: Zahlungsart und Skontobetrag in SEPA-Auftrag speichern
-- @depends: release_3_2_0
-- @ignore: 0

ALTER TABLE sepa_export_items ADD COLUMN payment_type TEXT;
UPDATE sepa_export_items SET payment_type = 'without_skonto' WHERE payment_type IS NULL;
ALTER TABLE sepa_export_items ALTER COLUMN payment_type SET DEFAULT 'without_skonto';

ALTER TABLE sepa_export_items ADD COLUMN skonto_amount NUMERIC(25,5);
