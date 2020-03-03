-- @tag: defaults_zugferd_test_mode
-- @description: ZUGFeRD optional nur im Test-Modus
-- @depends: defaults_create_zugferd_data
ALTER TABLE defaults
ALTER COLUMN create_zugferd_invoices TYPE INTEGER
USING create_zugferd_invoices::INTEGER;
