-- @tag: bank_account_flag_for_zugferd_usage
-- @description: Bankkonto für die Nutzung mit ZUGFeRD markieren
-- @depends: release_3_5_5
ALTER TABLE bank_accounts
ADD COLUMN use_for_zugferd BOOLEAN;

UPDATE bank_accounts
SET use_for_zugferd = (
  SELECT COUNT(*)
  FROM bank_accounts
) = 1;

ALTER TABLE bank_accounts
ALTER COLUMN use_for_zugferd SET DEFAULT FALSE,
ALTER COLUMN use_for_zugferd SET NOT NULL;
