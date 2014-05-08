-- @tag: bank_accounts_add_name
-- @description: Bankkonten bekommen nun einen Namen
-- @depends: release_3_1_0 bank_accounts

ALTER TABLE bank_accounts ADD COLUMN name text;
