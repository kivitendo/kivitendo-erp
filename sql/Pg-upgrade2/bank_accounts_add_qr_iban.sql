-- @tag: bank_accounts_add_qr_iban
-- @description: Bankkonto Informationen Spalte für QR-IBAN hinzufügen
-- @depends: release_3_9_0
ALTER TABLE bank_accounts ADD COLUMN qr_iban TEXT;
