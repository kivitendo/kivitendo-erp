-- @tag: order_type
-- @description: Persistente Typen in Aufträgen
-- @depends: release_3_7_0 oe_sales_order_intake_type

CREATE TYPE order_types AS ENUM (
  'request_quotation',
  'sales_quotation',
  'purchase_quotation_intake',
  'purchase_order',
  'sales_order_intake',
  'sales_order'
);

ALTER TABLE oe ADD COLUMN record_type order_types;

UPDATE oe SET record_type = 'sales_order'
  WHERE customer_id IS NOT NULL and (quotation = FALSE or quotation is null) and intake = FALSE;
UPDATE oe SET record_type = 'purchase_order'
  WHERE vendor_id   IS NOT NULL and (quotation = FALSE or quotation is null) and intake = FALSE;

UPDATE oe SET record_type = 'sales_quotation'
  WHERE customer_id IS NOT NULL and quotation = TRUE and intake = FALSE;
UPDATE oe SET record_type = 'request_quotation'
  WHERE vendor_id   IS NOT NULL and quotation = TRUE and intake = FALSE;

UPDATE oe SET record_type = 'sales_order_intake'
  WHERE customer_id IS NOT NULL and (quotation = FALSE or quotation is null) and intake = TRUE;
UPDATE oe SET record_type = 'purchase_quotation_intake'
  WHERE vendor_id   IS NOT NULL and quotation = TRUE and intake = TRUE;


ALTER TABLE oe ALTER COLUMN record_type SET NOT NULL;

ALTER TABLE oe DROP COLUMN quotation;
ALTER TABLE oe DROP COLUMN intake;
