-- @tag: customer_vendor_addd_shortname
-- @description: Add a short name for DATEV export to customer and vendor tables
ALTER TABLE customer ADD COLUMN shortname character(20);
ALTER TABLE vendor   ADD COLUMN shortname character(20);
