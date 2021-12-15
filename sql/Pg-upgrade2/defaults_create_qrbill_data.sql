-- @tag: defaults_create_qrbill_data
-- @description: Swiss QR-Bill Informationserzeugung Einstellungsoption
-- @depends: release_3_5_6_1
ALTER TABLE defaults ADD COLUMN create_qrbill_invoices BOOLEAN;
UPDATE defaults SET create_qrbill_invoices = FALSE;
