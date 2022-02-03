-- @tag: ar_add_qrbill_without_amount
-- @description: Spalte für QR-Rechnung ohne Betrag
-- @depends: release_3_5_8
ALTER TABLE ar ADD COLUMN qrbill_without_amount boolean;
ALTER TABLE ar ALTER COLUMN qrbill_without_amount SET DEFAULT FALSE;
UPDATE ar SET qrbill_without_amount = FALSE;
