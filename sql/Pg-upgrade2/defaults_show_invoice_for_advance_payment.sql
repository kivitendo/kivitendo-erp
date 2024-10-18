-- @tag: defaults_show_invoice_for_advance_payment
-- @description: Mandantenkonfiguration zum Anzeigen von Anzahlungs-/Schluss-Rechnungen (Menü/Workflows)
-- @depends: release_3_9_0

ALTER TABLE defaults ADD COLUMN show_invoice_for_advance_payment BOOLEAN NOT NULL DEFAULT TRUE;
