-- @tag: files
-- @description: Tabelle für Files
-- @depends: release_3_4_1
CREATE TABLE files(
  id                          SERIAL PRIMARY KEY,
  object_type                 TEXT NOT NULL,    -- Tabellenname des Moduls z.B. customer, parts ... Fremdschlüssel Zusammen mit object_id
  object_id                   INTEGER NOT NULL, -- Fremdschlüssel auf die id der Tabelle aus Spalte object_type
  file_name                   TEXT NOT NULL,
  file_type                   TEXT NOT NULL,
  mime_type                   TEXT NOT NULL,
  source                      TEXT NOT NULL,
  backend                     TEXT,
  backend_data                TEXT,
  title                       varchar(45),
  description                 TEXT,
  itime                       TIMESTAMP DEFAULT now(),
  mtime                       TIMESTAMP,
  CONSTRAINT valid_type CHECK (
             (object_type = 'credit_note') OR (object_type = 'invoice') OR (object_type = 'sales_order') OR (object_type = 'sales_quotation')
          OR (object_type = 'sales_delivery_order') OR (object_type = 'request_quotation') OR (object_type = 'purchase_order')
          OR (object_type = 'purchase_delivery_order') OR (object_type = 'purchase_invoice')
          OR (object_type = 'vendor') OR (object_type = 'customer') OR (object_type = 'part') OR (object_type = 'gl_transaction')
          OR (object_type = 'dunning') OR (object_type = 'dunning1') OR (object_type = 'dunning2') OR (object_type = 'dunning3')
          OR (object_type = 'draft') OR (object_type = 'statement'))
);
