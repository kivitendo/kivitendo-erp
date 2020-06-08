-- @tag: customer_create_zugferd_invoices
-- @description: Kundenstammdaten: Einstellungen für ZUGFeRD-Rechnungen
-- @depends: release_3_5_5
ALTER TABLE customer
ADD COLUMN create_zugferd_invoices INTEGER
DEFAULT -1 NOT NULL;
