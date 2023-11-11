-- @tag: email_journal_record_import_types
-- @description: vorgesehener Beleg Typ seperat in E-Mail-Journal speichern
-- @depends: release_3_8_0 email_journal_extend_status

-- UNDO: ALTER TYPE email_journal_status ADD VALUE 'record_imported' AFTER 'imported';
CREATE TYPE email_journal_status_new AS ENUM ('sent', 'send_failed', 'imported');
ALTER TABLE email_journal ADD COLUMN status_new email_journal_status_new;
UPDATE email_journal SET status_new = 'imported'    WHERE status = 'record_imported';
UPDATE email_journal SET status_new = 'imported'    WHERE status = 'imported';
UPDATE email_journal SET status_new = 'sent'        WHERE status = 'sent';
UPDATE email_journal SET status_new = 'send_failed' WHERE status = 'send_failed';
ALTER TABLE email_journal DROP COLUMN status;
ALTER TABLE email_journal RENAME COLUMN status_new TO status;
ALTER TABLE email_journal ALTER COLUMN status SET NOT NULL;
DROP TYPE email_journal_status;
ALTER TYPE email_journal_status_new RENAME TO email_journal_status;

CREATE TYPE email_journal_record_type AS ENUM (
  -- order
  'sales_order', 'purchase_order', 'sales_quotation', 'request_quotation',
  'purchase_quotation_intake', 'sales_order_intake',
  -- delivery order
  'sales_delivery_order', 'purchase_delivery_order',
  'supplier_delivery_order', 'rma_delivery_order',
  -- reclamation
  'sales_reclamation', 'purchase_reclamation',
  -- invoice
  'invoice', 'invoice_for_advance_payment',
  'invoice_for_advance_payment_storno', 'final_invoice', 'invoice_storno',
  'credit_note', 'credit_note_storno',
  -- purchase invoice
  'purchase_invoice', 'purchase_credit_note',
  --transaction
  'ap_transaction', 'ar_transaction', 'gl_transaction'
);
ALTER TABLE email_journal ADD COLUMN record_type email_journal_record_type;
