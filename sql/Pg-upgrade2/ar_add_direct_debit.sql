-- @tag: ar_add_direct_debit
-- @description: Spalte für Bankeinzug bei Verkaufsrechnungen
-- @depends: release_3_0_0
ALTER TABLE ar ADD COLUMN direct_debit boolean;
ALTER TABLE ar ALTER COLUMN direct_debit SET DEFAULT FALSE;
UPDATE ar SET direct_debit = FALSE;
