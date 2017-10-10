-- @tag: invoices_amount_paid_not_null
-- @description: Bei Rechnungen die drei Spalten "amount", "netamount" und "paid" auf NOT NULL setzen
-- @depends: release_3_2_0

UPDATE ar SET amount    = 0 WHERE amount    IS NULL;
ALTER TABLE ar ALTER COLUMN amount    SET NOT NULL;
ALTER TABLE ar ALTER COLUMN amount    SET DEFAULT 0;
UPDATE ar SET netamount = 0 WHERE netamount IS NULL;
ALTER TABLE ar ALTER COLUMN netamount SET NOT NULL;
ALTER TABLE ar ALTER COLUMN netamount SET DEFAULT 0;
UPDATE ar SET paid      = 0 WHERE paid      IS NULL;
ALTER TABLE ar ALTER COLUMN paid      SET NOT NULL;
ALTER TABLE ar ALTER COLUMN paid      SET DEFAULT 0;

UPDATE ap SET amount    = 0 WHERE amount    IS NULL;
ALTER TABLE ap ALTER COLUMN amount    SET NOT NULL;
ALTER TABLE ap ALTER COLUMN amount    SET DEFAULT 0;
UPDATE ap SET netamount = 0 WHERE netamount IS NULL;
ALTER TABLE ap ALTER COLUMN netamount SET NOT NULL;
ALTER TABLE ap ALTER COLUMN netamount SET DEFAULT 0;
UPDATE ap SET paid      = 0 WHERE paid      IS NULL;
ALTER TABLE ap ALTER COLUMN paid      SET NOT NULL;
ALTER TABLE ap ALTER COLUMN paid      SET DEFAULT 0;
