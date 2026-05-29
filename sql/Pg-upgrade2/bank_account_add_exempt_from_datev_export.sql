-- @tag: bank_account_add_exempt_from_datev_export
-- @description: Bankkonten: Einstellung von DATEV-Export ausnehmen hinzufügen
-- @depends: release_4_0_0

ALTER TABLE bank_accounts ADD COLUMN exempt_from_datev_export BOOLEAN NOT NULL default false;
