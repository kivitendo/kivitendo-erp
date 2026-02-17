-- @tag: countries_upgrade_customer_vendor
-- @description: Table for countries
-- @depends: release_4_0_0 countries


ALTER TABLE customer ADD column country_id INTEGER REFERENCES countries(id);
ALTER TABLE vendor   ADD column country_id INTEGER REFERENCES countries(id);

ALTER TABLE shipto                       ADD column shiptocountry_id INTEGER REFERENCES countries(id);
ALTER TABLE additional_billing_addresses ADD column country_id       INTEGER REFERENCES countries(id);
