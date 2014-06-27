-- @tag: defaults_sales_purchase_process_limitations
-- @description: Mandantenkonfiguration: Einschränkungen, welche Aktionen im Einkaufs-/Verkaufsprozess erlaubt sind
-- @depends: release_3_1_0
ALTER TABLE defaults
  ADD COLUMN allow_sales_invoice_from_sales_quotation BOOLEAN,
  ADD COLUMN allow_sales_invoice_from_sales_order     BOOLEAN,
  ADD COLUMN allow_new_purchase_delivery_order        BOOLEAN,
  ADD COLUMN allow_new_purchase_invoice               BOOLEAN;

UPDATE defaults
SET allow_sales_invoice_from_sales_quotation = TRUE,
    allow_sales_invoice_from_sales_order     = TRUE,
    allow_new_purchase_delivery_order        = TRUE,
    allow_new_purchase_invoice               = TRUE;

ALTER TABLE defaults
  ALTER COLUMN allow_sales_invoice_from_sales_quotation SET DEFAULT TRUE,
  ALTER COLUMN allow_sales_invoice_from_sales_quotation SET NOT NULL,

  ALTER COLUMN allow_sales_invoice_from_sales_order     SET DEFAULT TRUE,
  ALTER COLUMN allow_sales_invoice_from_sales_order     SET NOT NULL,

  ALTER COLUMN allow_new_purchase_delivery_order        SET DEFAULT TRUE,
  ALTER COLUMN allow_new_purchase_delivery_order        SET NOT NULL,

  ALTER COLUMN allow_new_purchase_invoice               SET DEFAULT TRUE,
  ALTER COLUMN allow_new_purchase_invoice               SET NOT NULL;
