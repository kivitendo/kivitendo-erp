-- @tag: countries_upgrade_customer_vendor_3
-- @description: Table for countries
-- @depends: release_3_2_0 countries_upgrade_customer_vendor_2


ALTER TABLE customer ALTER COLUMN country_id SET NOT NULL;
ALTER TABLE vendor   ALTER COLUMN country_id SET NOT NULL;
