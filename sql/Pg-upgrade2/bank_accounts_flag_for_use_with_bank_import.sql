-- @tag: bank_accounts_flag_for_use_with_bank_import
-- @description: Bankkonto für die Nutzung mit dem Bank Import markieren
-- @depends: release_3_8_0
ALTER TABLE bank_accounts ADD COLUMN use_with_bank_import BOOLEAN NOT NULL DEFAULT true;
