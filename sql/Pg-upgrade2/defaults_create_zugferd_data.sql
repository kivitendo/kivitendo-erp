-- @tag: defaults_create_zugferd_data
-- @description: ZUGFeRD-Informationserzeugung option abstellen
-- @depends: release_3_5_5
ALTER TABLE defaults ADD COLUMN create_zugferd_invoices BOOLEAN;
UPDATE defaults SET create_zugferd_invoices = TRUE;
