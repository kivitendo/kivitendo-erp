-- @tag: ap_add_direct_debit
-- @description: Spalte für Bankeinzug bei Einkaufsrechnungen
-- @depends: release_3_0_0
ALTER TABLE ap ADD COLUMN direct_debit boolean;
ALTER TABLE ap ALTER COLUMN direct_debit SET DEFAULT FALSE;
UPDATE ap SET direct_debit = FALSE;
