-- @tag: defaults_add_subtract_credit-notes
-- @description: Mandantekonfig: SEPA Zahlungen zusammenfassen, Gutschriften abziehen
-- @depends: release_3_9_1

ALTER TABLE defaults ADD COLUMN sepa_combine_payments boolean DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN sepa_subtract_credit_notes boolean DEFAULT TRUE;

