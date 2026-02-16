-- @tag: countries_upgrade_customer_vendor
-- @description: Table for countries
-- @depends: release_3_2_0 countries


ALTER TABLE customer ADD column country_id INTEGER REFERENCES countries(id);
ALTER TABLE vendor   ADD column country_id INTEGER REFERENCES countries(id);
