-- @tag: bank_account_information_for_swiss_qrbill
-- @description: Bankkonto Informationen für Swiss QR-Bill hinzufügen
-- @depends: release_3_5_6_1
ALTER TABLE bank_accounts ADD COLUMN use_for_qrbill BOOLEAN;
ALTER TABLE bank_accounts ADD COLUMN bank_account_id VARCHAR;

UPDATE bank_accounts SET use_for_qrbill = (
    SELECT COUNT(*)
    FROM bank_accounts
  ) = 1;

ALTER TABLE bank_accounts
  ALTER COLUMN use_for_qrbill SET DEFAULT FALSE,
  ALTER COLUMN use_for_qrbill SET NOT NULL;
