-- @tag: bank_transactions_add_qr_reference
-- @description: Erweitern der Tabelle bank_transactions mit Spalte für QR-Referenz.
-- @depends: release_3_6_1
ALTER TABLE bank_transactions ADD COLUMN qr_reference TEXT;
