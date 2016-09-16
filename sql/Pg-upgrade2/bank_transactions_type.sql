-- @tag: bank_transactions_type
-- @description: Erweitern der Tabelle bank_transactions mit Typ der Transaktion.
-- @depends: bank_transactions

ALTER TABLE bank_transactions ADD COLUMN transactionCode TEXT;
ALTER TABLE bank_transactions ADD COLUMN transactionText TEXT;
