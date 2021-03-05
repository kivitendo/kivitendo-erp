-- @tag: file_storage_type_letter
-- @description: Letter als valid_type für Filemanagement
-- @depends: shopimages

ALTER TABLE files
  DROP CONSTRAINT valid_type;
ALTER TABLE files
  ADD  CONSTRAINT valid_type CHECK (
             (object_type = 'credit_note'     ) OR (object_type = 'invoice'                 ) OR (object_type = 'sales_order'       )
          OR (object_type = 'sales_quotation' ) OR (object_type = 'sales_delivery_order'    ) OR (object_type = 'request_quotation' )
          OR (object_type = 'purchase_order'  ) OR (object_type = 'purchase_delivery_order' ) OR (object_type = 'purchase_invoice'  )
          OR (object_type = 'vendor'          ) OR (object_type = 'customer'                ) OR (object_type = 'part'              )
          OR (object_type = 'gl_transaction'  ) OR (object_type = 'dunning'                 ) OR (object_type = 'dunning1'          )
          OR (object_type = 'dunning2'        ) OR (object_type = 'dunning3'                ) OR (object_type = 'draft'             )
          OR (object_type = 'statement'       ) OR (object_type = 'shop_image'              ) OR (object_type = 'letter'            )
  );
