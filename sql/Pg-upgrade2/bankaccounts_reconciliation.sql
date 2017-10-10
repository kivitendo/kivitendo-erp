-- @tag: bankaccounts_reconciliation
-- @description: Kontenabgleichsststartdatum und -saldo
-- @depends: release_3_2_0

ALTER TABLE bank_accounts ADD COLUMN reconciliation_starting_date DATE;
ALTER TABLE bank_accounts ADD COLUMN reconciliation_starting_balance numeric(15,5);
