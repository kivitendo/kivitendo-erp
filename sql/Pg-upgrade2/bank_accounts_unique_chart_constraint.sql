-- @tag: bank_accounts_unique_chart_constraint
-- @description: Bankkonto - Constraint für eindeutiges Konto
-- @depends: release_3_2_0 bank_accounts

ALTER TABLE bank_accounts ADD CONSTRAINT chart_id_unique UNIQUE (chart_id);
