-- @tag: defaults_qrbill_variants
-- @description: Varianten für QR-Rechnung Auswahl
-- @depends: defaults_create_qrbill_data
ALTER TABLE defaults
ALTER COLUMN create_qrbill_invoices TYPE INTEGER
USING create_qrbill_invoices::INTEGER;
