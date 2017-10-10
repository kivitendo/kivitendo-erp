-- @tag:shopimages
-- @description: Tabelle für Shopbilder und zusätzliche Konfiguration und valid_type für Filemanagement
-- @depends: release_3_5_0 files shop_parts
-- @ignore: 0

CREATE TABLE shop_images(
  id                      SERIAL PRIMARY KEY,
  file_id                 INTEGER REFERENCES files(id) ON DELETE CASCADE,
  position                INTEGER,
  thumbnail_content       BYTEA,
  thumbnail_width         INTEGER,
  thumbnail_height        INTEGER,
  thumbnail_content_type  TEXT,
  itime                   TIMESTAMP DEFAULT now(),
  mtime                   TIMESTAMP
);

CREATE TRIGGER mtime_shop_images BEFORE UPDATE ON shop_images FOR EACH ROW EXECUTE PROCEDURE set_mtime();

ALTER TABLE defaults ADD COLUMN doc_storage_for_shopimages      text default 'Filesystem';

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
          OR (object_type = 'statement'       ) OR (object_type = 'shop_image'              )
  );
