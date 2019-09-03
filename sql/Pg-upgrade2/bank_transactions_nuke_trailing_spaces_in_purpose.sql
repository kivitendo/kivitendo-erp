-- @tag: bank_transactions_nuke_trailing_spaces_in_purpose
-- @description: Banktransaktionen: überflüssige Leerzeichen am Ende des Verwendungszwecks entfernen
-- @depends: release_3_5_4
UPDATE bank_transactions
SET purpose = regexp_replace(purpose, ' +$', '')
WHERE purpose ~ ' +$';
