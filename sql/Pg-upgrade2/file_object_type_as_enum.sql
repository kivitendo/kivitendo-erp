-- @tag: file_object_type_as_enum
-- @description: Objekttype von Dateien in Enum ändern
-- @depends: files file_storage_purchase_quotation_intake
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

-- constraint aus file_storage_purchase_quotation_intake wiederherstellen:
ALTER TABLE files
  ADD  CONSTRAINT valid_type CHECK (
             (object_type = 'credit_note'                 ) OR (object_type = 'invoice'                   )
          OR (object_type = 'sales_order'                 ) OR (object_type = 'sales_order_intake'        )
          OR (object_type = 'sales_quotation'             ) OR (object_type = 'sales_delivery_order'      )
          OR (object_type = 'request_quotation'           ) OR (object_type = 'purchase_quotation_intake' ) OR (object_type = 'purchase_order'          )
          OR (object_type = 'purchase_delivery_order'     ) OR (object_type = 'purchase_invoice'          )
          OR (object_type = 'vendor'                      ) OR (object_type = 'customer'                  ) OR (object_type = 'part'                    )
          OR (object_type = 'gl_transaction'              ) OR (object_type = 'dunning'                   ) OR (object_type = 'dunning1'                )
          OR (object_type = 'dunning2'                    ) OR (object_type = 'dunning3'                  ) OR (object_type = 'dunning_orig_invoice'    )
          OR (object_type = 'dunning_invoice'             ) OR (object_type = 'draft'                     ) OR (object_type = 'statement'               )
          OR (object_type = 'shop_image'                  ) OR (object_type = 'letter'                    ) OR (object_type = 'project'                 )
          OR (object_type = 'invoice_for_advance_payment' ) OR (object_type = 'final_invoice'             ) OR (object_type = 'supplier_delivery_order' )
          OR (object_type = 'sales_reclamation'           ) OR (object_type = 'purchase_reclamation'      ) OR (object_type = 'rma_delivery_order'      )
  );

