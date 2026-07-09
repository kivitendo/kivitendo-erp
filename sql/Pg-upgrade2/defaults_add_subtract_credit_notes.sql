-- @tag: defaults_add_subtract_credit-notes
-- @description: Mandantekonfig: SEPA Zahlungen zusammenfassen, Gutschriften abziehen
-- @depends: release_4_0_0

ALTER TABLE defaults ADD COLUMN sepa_combine_payments boolean DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN sepa_subtract_credit_notes boolean DEFAULT TRUE;

