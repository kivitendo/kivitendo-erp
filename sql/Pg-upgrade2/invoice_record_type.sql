-- @tag: invoice_record_type
-- @description: Persistente Typen in Rechnungen
-- @depends: release_3_9_1

CREATE TYPE invoice_types AS ENUM (
  'ar_transaction',
  'ar_transaction_storno',
  'invoice',
  'invoice_storno',
  'invoice_for_advance_payment',
  'invoice_for_advance_payment_storno',
  'final_invoice',
  'credit_note',
  'credit_note_storno'
);

ALTER TABLE ar ADD COLUMN record_type invoice_types;

UPDATE ar SET record_type = 'ar_transaction_storno'
  WHERE record_type IS NULL and (invoice = FALSE or invoice IS NULL) and storno = TRUE;
UPDATE ar SET record_type = 'ar_transaction'
  WHERE record_type IS NULL and (invoice = FALSE or invoice IS NULL);

UPDATE ar SET record_type = 'invoice_for_advance_payment_storno'
  WHERE record_type IS NULL and type = 'invoice_for_advance_payment' and amount < 0 and storno = TRUE;
UPDATE ar SET record_type = 'invoice_for_advance_payment'
  WHERE record_type IS NULL and type = 'invoice_for_advance_payment';

UPDATE ar SET record_type = 'final_invoice'
  WHERE record_type IS NULL and type = 'final_invoice';

UPDATE ar SET record_type = 'credit_note'
  WHERE record_type IS NULL and type = 'credit_note' and amount < 0;
UPDATE ar SET record_type = 'credit_note_storno'
  WHERE record_type IS NULL and type = 'credit_note' and amount > 0 and storno = TRUE;

UPDATE ar SET record_type = 'invoice_storno'
  WHERE record_type IS NULL and type != 'credit_note' and amount < 0 and storno = TRUE;

UPDATE ar SET record_type = 'invoice'
  WHERE record_type IS NULL and amount >= 0;


ALTER TABLE ar ALTER COLUMN record_type SET NOT NULL;

CREATE TYPE purchase_invoice_types AS ENUM (
  'ap_transaction',
  'ap_transaction_storno',
  'purchase_invoice',
  'purchase_invoice_storno',
  'purchase_credit_note',
  'purchase_credit_note_storno'
);

ALTER TABLE ap ADD COLUMN record_type purchase_invoice_types;

UPDATE ap SET record_type = 'ap_transaction'
  WHERE record_type IS NULL and (invoice = FALSE or invoice IS NULL);
UPDATE ap SET record_type = 'ap_transaction_storno'
  WHERE record_type IS NULL and (invoice = FALSE or invoice IS NULL) and storno = TRUE;

UPDATE ap SET record_type = 'purchase_credit_note'
  WHERE record_type IS NULL and amount < 0 and (storno = FALSE or invoice IS NULL);
UPDATE ap SET record_type = 'purchase_credit_note_storno'
  WHERE record_type IS NULL and amount > 0 and storno = TRUE;

UPDATE ap SET record_type = 'purchase_invoice'
  WHERE record_type IS NULL and amount >= 0 and (storno = FALSE or invoice IS NULL);
UPDATE ap SET record_type = 'purchase_invoice_storno'
  WHERE record_type IS NULL and amount <= 0 and storno = TRUE;

ALTER TABLE ar ALTER COLUMN record_type SET NOT NULL;
