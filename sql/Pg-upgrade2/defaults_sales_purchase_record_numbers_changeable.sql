-- @tag: defaults_sales_purchase_record_numbers_changeable
-- @description: Verkauf: Belegnummern nicht mehr ändern können
-- @depends: release_3_5_8
ALTER TABLE defaults
ADD COLUMN sales_purchase_record_numbers_changeable BOOLEAN
DEFAULT FALSE NOT NULL;
