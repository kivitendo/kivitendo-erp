-- @tag: file_object_type_as_enum
-- @description: Objekttype von Dateien in Enum ändern
-- @depends: files file_storage_purchase_order_confirmation
-- @ignore: 0


CREATE TYPE file_object_types AS ENUM (
  -- order
 'sales_quotation',
 'sales_order',
 'sales_order_intake',
 'request_quotation',
 'purchase_quotation_intake',
 'purchase_order',
 'purchase_order_confirmation',
  -- delivery_order
 'sales_delivery_order',
 'supplier_delivery_order',
 'purchase_delivery_order',
 'rma_delivery_order',
  -- invoice
 'invoice',
 'invoice_for_advance_payment',
 'final_invoice',
 'credit_note',
 'purchase_invoice',
  -- reclamation
 'sales_reclamation',
 'purchase_reclamation',
  -- dunning
 'dunning',
 'dunning1',
 'dunning2',
 'dunning3',
 'dunning_orig_invoice',
 'dunning_invoice',
  -- cv
 'customer',
 'vendor',
  -- other
 'gl_transaction',
 'part',
 'shop_image',
 'draft',
 'letter',
 'project',
 'statement'
);

ALTER TABLE files ADD    COLUMN object_type_new file_object_types;
UPDATE files SET object_type_new = object_type::file_object_types;
ALTER TABLE files ALTER  COLUMN object_type_new SET NOT NULL;
ALTER TABLE files DROP   COLUMN object_type;
ALTER TABLE files RENAME COLUMN object_type_new TO object_type;


