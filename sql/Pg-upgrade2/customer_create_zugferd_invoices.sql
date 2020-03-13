-- @tag: customer_create_zugferd_invoices
-- @description: Kundenstammdaten: Einstellungen für ZUGFeRD-Rechnungen
-- @depends: release_3_5_5
ALTER TABLE customer
ADD COLUMN create_zugferd_invoices INTEGER;

UPDATE customer
SET create_zugferd_invoices = -1;

ALTER TABLE customer
ALTER COLUMN create_zugferd_invoices SET DEFAULT -1,
ALTER COLUMN create_zugferd_invoices SET NOT NULL;
