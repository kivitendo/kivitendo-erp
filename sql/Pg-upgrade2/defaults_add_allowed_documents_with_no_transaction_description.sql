-- @tag: defaults_add_allowed_documents_with_no_transaction_description
-- @description: Mandantenkonfiguration, um das Setzen der Vorgangsbezeichnung einzufordern
-- @depends: release_4_1_0

ALTER TABLE defaults ADD COLUMN allowed_documents_with_no_transaction_description TEXT[];

UPDATE defaults SET allowed_documents_with_no_transaction_description = '{
  "sales_quotation",
  "request_quotation",
  "sales_order_intake",
  "purchase_quotation_intake",
  "sales_order",
  "purchase_order",
  "purchase_order_confirmation",

  "sales_delivery_order",
  "purchase_delivery_order",
  "supplier_delivery_order",
  "rma_delivery_order",

  "sales_reclamation",
  "purchase_reclamation",

  "ar_transaction",
  "invoice",
  "invoice_for_advance_payment",
  "final_invoice",
  "credit_note",

  "ap_transaction",
  "purchase_invoice",
  "purchase_credit_note",

  "gl_transaction"
}'
WHERE EXISTS ( SELECT 1 FROM defaults WHERE require_transaction_description_ps = false );

ALTER TABLE defaults DROP COLUMN require_transaction_description_ps;
