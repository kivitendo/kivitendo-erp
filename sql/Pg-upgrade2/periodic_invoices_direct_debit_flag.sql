-- @tag: periodic_invoices_direct_debit_flag
-- @description: Flag Lastschrifteinzug bei wiederkehrenden Rechnungen
-- @depends: release_3_3_0
ALTER TABLE periodic_invoices_configs ADD COLUMN direct_debit BOOLEAN DEFAULT FALSE;
UPDATE periodic_invoices_configs SET direct_debit = FALSE;
ALTER TABLE periodic_invoices_configs ALTER COLUMN direct_debit SET NOT NULL;
